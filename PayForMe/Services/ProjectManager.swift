//
//  DataManager.swift
//  PayForMe
//
//  Created by Camille Mainz on 04.02.20.
//

import Combine
import Foundation
import UIKit

class ProjectManager: ObservableObject {
    // Expose for testing
    func performMergeBillsTest(local: [Bill], oldServer: [Bill], freshServer: [Bill]) -> [Bill] {
        return mergeBills(local: local, oldServer: oldServer, freshServer: freshServer)
    }

    /// Merge local unsynced bills (with negative IDs) with truly new server bills, matching by content to avoid duplicates and preserve unsynced bills
    /// - Parameters:
    ///   - local: All local bills (including unsynced)
    ///   - oldServer: Bills that existed on the server before sync
    ///   - freshServer: Bills just downloaded from the server after sync
    /// - Returns: The merged list of bills
    private func mergeBills(local: [Bill], oldServer: [Bill], freshServer: [Bill]) -> [Bill] {
        // Only consider local bills with negative IDs (not yet on server)
        let localUnsynced = local.filter { $0.id < 0 }

        // Find truly new server bills (those in freshServer but not in oldServer, by id)
        let oldServerIDs = Set(oldServer.map { $0.id })
        let newServerBills = freshServer.filter { !oldServerIDs.contains($0.id) }

        // Start with all fresh server bills
        var merged = freshServer
        for localBill in localUnsynced {
            let exists = newServerBills.contains { serverBill in
                let amountMatch = abs(serverBill.amount - localBill.amount) < 0.01
                let whatMatch = serverBill.what == localBill.what
                let payerMatch = serverBill.payer_id == localBill.payer_id
                let owersMatch = Set(serverBill.owers.map { $0.id }) == Set(localBill.owers.map { $0.id })
                let repeatMatch = serverBill.repeat == localBill.repeat
                // Add more fields if needed
                let match = amountMatch && whatMatch && payerMatch && owersMatch && repeatMatch
                return match
            }
            if !exists {
                merged.append(localBill)
            }
        }
        return merged
    }
    private let defaults = UserDefaults.standard

    private var cancellable: Cancellable?

    @Published
    private(set) var projects = [Project]()

    @Published
    var currentProject: Project = demoProject

    let storageService = StorageService()

    static let shared = ProjectManager()

    @Published var openedByURL: URL?
    
    // Offline status tracking
    @Published var isOffline: Bool = false
    @Published var lastSyncDate: Date?
    private var networkMonitorCancellable: AnyCancellable?
    
    // Local changes tracking
    @Published var localBillsToUpload: Set<Int> = []
    @Published var localMembersToUpload: Set<Int> = []
    @Published var localBillsToDelete: Set<Int> = []
    @Published var localMembersToDelete: Set<Int> = []

    private init() {
        print("init")
        projects = storageService.loadProjects()

        let id = defaults.integer(forKey: "projectID")
        if let project = projects.first(where: {
            $0.id == id
        }) {
            currentProject = project
            // Load last sync date from cache
            lastSyncDate = defaults.object(forKey: "lastSyncDate_\(project.id ?? 0)") as? Date
            // Start as potentially offline until we confirm connection
            isOffline = true
            // Load cached data first to ensure bills are always visible
            loadCachedData()
            loadBillsAndMembers()
        } else {
            if !projects.isEmpty {
                currentProject = projects[0]
                isOffline = true
                // Load cached data first to ensure bills are always visible
                loadCachedData()
            }
        }
        
        // Set up automatic retry when app becomes active
        setupNetworkMonitoring()
    }

    func openedByURL(url: URL) {
        let data = url.decodeCospendString()
        guard let _ = data.server,
              let _ = data.project
        else {
            return
        }
        openedByURL = url
    }

    // MARK: Server Communication

    func loadBillsAndMembers() {
        _ = currentProject
        
        // Always load cached data first - makes app work transparently
        loadCachedData()
        
        // Try to sync in background without blocking UI
        Task {
            await syncData()
        }
    }
    
    func loadBillsAndMembersLegacy() {
        let project = currentProject
        
        // Load cached data first
        loadCachedData()

        _ = NetworkService.shared.loadBillsPublisher(project)
        _ = NetworkService.shared.loadMembersPublisher(project)

        Publishers.Zip(
            NetworkService.shared.loadBillsWithStatusPublisher(project),
            NetworkService.shared.loadMembersWithStatusPublisher(project)
        )
        .map { billsResult, membersResult in
            var networkSuccess = false
            
            // Handle bills result
            switch billsResult {
            case .success(let fetchedBills):
                project.bills = fetchedBills
                networkSuccess = true
            case .failure:
                // Keep existing bills from cache (already loaded)
                break
            }
            
            // Handle members result
            switch membersResult {
            case .success(let fetchedMembers):
                project.members = fetchedMembers
                networkSuccess = true
            case .failure:
                // Keep existing members from cache (already loaded)
                break
            }
            
            // Update offline status
            if networkSuccess {
                self.isOffline = false
                self.lastSyncDate = Date()
                
                // Cache the fresh data
                self.cacheProjectData(project: project, bills: project.bills, members: project.members)
            } else {
                self.isOffline = true
            }
            
            return project
        }
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentProject)
    }
    
    @MainActor
    func syncData() async {
        let project = currentProject
        
        // Load cached data first to ensure bills are always visible
        loadCachedData()
        
        do {
            // Upload any local changes first
            await uploadLocalChanges(project: project)

            // Then download fresh data from server
            async let billsTask = NetworkService.shared.loadBills(project)
            async let membersTask = NetworkService.shared.loadMembers(project)

            let freshBills = try await billsTask
            let freshMembers = try await membersTask

            // Merge local unsynced bills with only the truly new server bills
            let mergedBills = mergeBills(local: project.bills, oldServer: project.bills.filter { $0.id > 0 }, freshServer: freshBills)

            // Update the current project with merged data
            currentProject.bills = mergedBills
            currentProject.members = freshMembers

            // Cache the fresh data (cache merged bills)
            cacheProjectData(project: currentProject, bills: mergedBills, members: freshMembers)

            // Update sync status
            isOffline = false
            lastSyncDate = Date()
            defaults.set(lastSyncDate, forKey: "lastSyncDate_\(currentProject.id ?? 0)")

        } catch {
            print("Sync failed, staying offline: \(error)")
            isOffline = true
        }
    }
    
    private func uploadLocalChanges(project: Project) async {
        // Upload any bills that were created/modified locally
        let billsToUpload = Array(localBillsToUpload)
        var didUploadBill = false
        for billId in billsToUpload {
            if let billIndex = project.bills.firstIndex(where: { $0.id == billId }) {
                let bill = project.bills[billIndex]
                do {
                    // Try to upload the bill
                    if let newServerId = try await NetworkService.shared.uploadBill(bill, to: project) {
                        // For new bills with negative IDs, replace with server-assigned ID and remove the negative-ID bill
                        await MainActor.run {
                            var updatedBill = bill
                            updatedBill.id = newServerId
                            // Remove the negative-ID bill
                            currentProject.bills.removeAll(where: { $0.id == billId })
                            // Add the updated bill with the new server ID
                            currentProject.bills.append(updatedBill)
                            localBillsToUpload.remove(billId) // Remove old negative ID
                        }
                        didUploadBill = true
                    } else {
                        // Remove from local changes set if successful (update case)
                        await MainActor.run {
                            localBillsToUpload.remove(billId)
                        }
                    }
                } catch {
                    print("Failed to upload bill \(billId): \(error)")
                    // Keep in local changes set for next sync attempt
                }
            }
        }
        
        // Delete any bills that were deleted locally
        let billsToDelete = Array(localBillsToDelete)
        for billId in billsToDelete {
            do {
                // Try to delete the bill from server (only if it has positive ID)
                if billId > 0 {
                    try await NetworkService.shared.deleteBill(billId, from: project)
                }
                // Remove from local deletions set if successful
                await MainActor.run {
                    localBillsToDelete.remove(billId)
                }
            } catch {
                print("Failed to delete bill \(billId): \(error)")
                // Keep in local deletions set for next sync attempt
            }
        }
        
        // Upload any members that were created/updated locally
        let membersToUpload = Array(localMembersToUpload)
        for memberId in membersToUpload {
            if let member = project.members[memberId] {
                do {
                    // Try to upload the member
                    if let newServerId = try await NetworkService.shared.uploadMember(member, to: project) {
                        // For new members with negative IDs, update to server-assigned ID
                        await MainActor.run {
                            var updatedMember = member
                            updatedMember.id = newServerId
                            currentProject.members.removeValue(forKey: memberId) // Remove old negative ID
                            currentProject.members[newServerId] = updatedMember // Add with new positive ID
                            localMembersToUpload.remove(memberId) // Remove old negative ID
                            
                            // Update any bills that reference this member
                            updateBillMemberReferences(oldMemberId: memberId, newMemberId: newServerId, updatedMember: updatedMember)
                        }
                    } else {
                        // Remove from local changes set if successful (update case)
                        await MainActor.run {
                            localMembersToUpload.remove(memberId)
                        }
                    }
                } catch {
                    print("Failed to upload member \(memberId): \(error)")
                    // Keep in local changes set for next sync attempt
                }
            }
        }
        
        // Delete any members that were deleted locally
        let membersToDelete = Array(localMembersToDelete)
        for memberId in membersToDelete {
            do {
                // Try to delete the member from server (only if it has positive ID)
                if memberId > 0 {
                    try await NetworkService.shared.deleteMember(memberId, from: project)
                }
                // Remove from local deletions set if successful
                await MainActor.run {
                    localMembersToDelete.remove(memberId)
                }
            } catch {
                print("Failed to delete member \(memberId): \(error)")
                // Keep in local deletions set for next sync attempt
            }
        }
        // After all uploads/deletions, if any bills were uploaded, trigger a sync to fetch the latest server data
        if didUploadBill {
            await MainActor.run {
                Task {
                    await self.syncData()
                }
            }
        }
    }
    
    private func loadCachedData() {
        if let cachedData = loadCachedProjectData() {
            currentProject.bills = cachedData.bills
            currentProject.members = cachedData.members
            // Restore local change queues
            localBillsToUpload = cachedData.localBillsToUpload
            localMembersToUpload = cachedData.localMembersToUpload
            localBillsToDelete = cachedData.localBillsToDelete
            localMembersToDelete = cachedData.localMembersToDelete
        }
    }
    
    private func cacheProjectData(project: Project, bills: [Bill], members: [Int: Person]) {
        let cacheData = CachedProjectData(
            bills: bills,
            members: members,
            cachedAt: Date(),
            localBillsToUpload: localBillsToUpload,
            localMembersToUpload: localMembersToUpload,
            localBillsToDelete: localBillsToDelete,
            localMembersToDelete: localMembersToDelete
        )
        let cacheKey = "cached_project_\(project.id ?? 0)"
        
        if let encoded = try? JSONEncoder().encode(cacheData) {
            defaults.set(encoded, forKey: cacheKey)
        }
    }
    
    private func loadCachedProjectData() -> CachedProjectData? {
        let cacheKey = "cached_project_\(currentProject.id ?? 0)"
        
        guard let data = defaults.data(forKey: cacheKey) else {
            return nil
        }
        
        // First try to decode new format
        if let cachedData = try? JSONDecoder().decode(CachedProjectData.self, from: data) {
            return cachedData
        }
        
        // Fall back to old format for backward compatibility
        if let oldCachedData = try? JSONDecoder().decode(OldCachedProjectData.self, from: data) {
            return CachedProjectData(
                bills: oldCachedData.bills,
                members: oldCachedData.members,
                cachedAt: oldCachedData.cachedAt
            )
        }
        
        return nil
    }

    private func sendBillToServer(bill: Bill, update: Bool, completion: @escaping () -> Void) {
        cancellable?.cancel()
        cancellable = nil

        if update {
            cancellable = NetworkService.shared.updateBillPublisher(bill: bill)
                .sink { success in
                    if success {
                        print("Bill id\(bill.id) updated")
                    } else {
                        print("error updating bill id\(bill.id)")
                    }
                    completion()
                }
        } else {
            cancellable = NetworkService.shared.postBillPublisher(bill: bill)
                .sink { success in
                    if success {
                        print("Bill posted")
                    } else {
                        print("Error posting bill")
                    }
                    completion()
                }
        }
    }

    private func deleteBillFromServer(bill: Bill, completion: @escaping () -> Void) {
        cancellable?.cancel()
        cancellable = nil

        cancellable = NetworkService.shared.deleteBillPublisher(bill: bill)
            .sink { success in
                if success {
                    print("Bill successfully deleted")
                } else {
                    print("Error deleting bill")
                }
                completion()
            }
    }

    private func sendMemberToServer(_ member: Person, update: Bool, completion: @escaping () -> Void) {
        cancellable?.cancel()
        cancellable = nil

        if update {
            cancellable = NetworkService.shared.updateMemberPublisher(member: member)
                .sink { success in
                    if success {
                        print("Member id\(member.id) updated")
                    } else {
                        print("Error updating Member")
                    }
                    completion()
                }
        } else {
            cancellable = NetworkService.shared.createMemberPublisher(name: member.name)
                .sink { success in
                    if success {
                        print("Member successfully created")
                    } else {
                        print("Error creating member")
                    }
                    completion()
                }
        }
    }

    private func deleteMemberFromServer(_ member: Person, completion: @escaping () -> Void) {
        cancellable?.cancel()
        cancellable = nil

        cancellable = NetworkService.shared.deleteMemberPublisher(member: member)
            .sink { success in
                if success {
                    print("Member id\(member.id) successfully deleted")
                } else {
                    print("Error deleting member")
                }
                completion()
            }
    }
}

enum StoringError: Error {
    case couldNotSave
}

extension ProjectManager {
    func addProject(_ project: Project) throws {
        guard storageService.saveProject(project: project) else {
            throw StoringError.couldNotSave
        }
        DispatchQueue.main.async { [self] in
            projects = storageService.loadProjects()

            if projects.count == 1 {
                setCurrentProject(project)
            }
            openedByURL = nil
            print("project added")
        }
    }

    func deleteProject(_ project: Project) {
        storageService.removeProject(project: project)
        projects = storageService.loadProjects()
//        projects.removeAll {
//            $0 == project
//        }
        if currentProject == project {
            if let nextProject = projects.first {
                setCurrentProject(nextProject)
            }
        } else {
            currentProject = demoProject
        }
    }

    func prepareUITestOnboarding() {
        projects.forEach { deleteProject($0) }
    }

    func prepareUITest() throws {
        projects.forEach { deleteProject($0) }
        try addProject(demoProject)
    }

    func saveBill(_ bill: Bill, completion: @escaping () -> Void) {
        var billToSave = bill
        let isUpdate = bill.id != -1 && currentProject.bills.contains(where: { $0.id == bill.id })

        // Update local data immediately for transparent offline experience
        if isUpdate {
            if let index = currentProject.bills.firstIndex(where: { $0.id == bill.id }) {
                currentProject.bills[index] = billToSave
            }
        } else {
            // Assign temporary negative ID for new bills
            if billToSave.id == -1 {
                billToSave.id = -Int.random(in: 1000...999999) // Temporary negative ID
            }
            currentProject.bills.append(billToSave)
        }

        // Cache the updated data
        cacheProjectData(project: currentProject, bills: currentProject.bills, members: currentProject.members)

        // Track for upload when online
        localBillsToUpload.insert(billToSave.id)

        // Try to upload immediately if online, but don't block the UI
        Task {
            if !isOffline {
                do {
                    if let newServerId = try await NetworkService.shared.uploadBill(billToSave, to: currentProject) {
                        // For new bills with negative IDs, update to server-assigned ID
                        await MainActor.run {
                            // Remove the negative-ID bill if present
                            currentProject.bills.removeAll(where: { $0.id == billToSave.id })
                            localBillsToUpload.remove(billToSave.id)
                            // Add the updated bill with the new server ID
                            var updatedBill = billToSave
                            updatedBill.id = newServerId
                            currentProject.bills.append(updatedBill)
                            // Cache the updated data
                            cacheProjectData(project: currentProject, bills: currentProject.bills, members: currentProject.members)
                        }
                    } else {
                        // Remove from pending uploads if successful (update case)
                        await MainActor.run {
                            localBillsToUpload.remove(billToSave.id)
                        }
                    }
                } catch {
                    print("Failed to upload bill immediately: \(error)")
                    // Will be retried during next sync
                }
            }
        }

        // Always call completion immediately for responsive UI
        completion()
    }

    func deleteBill(_ bill: Bill, completion: @escaping () -> Void) {
        // Remove from local data immediately for transparent offline experience
        currentProject.bills.removeAll {
            $0.id == bill.id
        }
        
        // Cache the updated data
        cacheProjectData(project: currentProject, bills: currentProject.bills, members: currentProject.members)
        
        // Track for deletion when online (only if it has a positive ID, meaning it exists on server)
        if bill.id > 0 {
            localBillsToDelete.insert(bill.id)
            // Remove from upload queue if it was there
            localBillsToUpload.remove(bill.id)
        }
        
        // Try to delete immediately if online, but don't block the UI
        Task {
            if !isOffline && bill.id > 0 {
                do {
                    try await NetworkService.shared.deleteBill(bill.id, from: currentProject)
                    // Remove from pending deletions if successful
                    await MainActor.run {
                        localBillsToDelete.remove(bill.id)
                    }
                } catch {
                    print("Failed to delete bill immediately: \(error)")
                    // Will be retried during next sync
                }
            }
        }
        
        // Always call completion immediately for responsive UI
        completion()
    }

    func addMember(_ name: String, completion: @escaping () -> Void) {
        // Create member with temporary negative ID
        let tempId = -Int.random(in: 1000...999999)
        let newMember = Person(id: tempId, weight: 1, name: name, activated: true, color: nil)
        
        // Add to local data immediately for transparent offline experience
        currentProject.members[tempId] = newMember
        
        // Cache the updated data
        cacheProjectData(project: currentProject, bills: currentProject.bills, members: currentProject.members)
        
        // Track for upload when online
        localMembersToUpload.insert(tempId)
        
        // Try to upload immediately if online, but don't block the UI
        Task {
            if !isOffline {
                do {
                    if let newServerId = try await NetworkService.shared.uploadMember(newMember, to: currentProject) {
                        // For new members with negative IDs, update to server-assigned ID
                        await MainActor.run {
                            var updatedMember = newMember
                            updatedMember.id = newServerId
                            currentProject.members.removeValue(forKey: tempId) // Remove old negative ID
                            currentProject.members[newServerId] = updatedMember // Add with new positive ID
                            localMembersToUpload.remove(tempId) // Remove old negative ID
                            
                            // Update any bills that reference this member
                            updateBillMemberReferences(oldMemberId: tempId, newMemberId: newServerId, updatedMember: updatedMember)
                            
                            // Cache the updated data
                            cacheProjectData(project: currentProject, bills: currentProject.bills, members: currentProject.members)
                        }
                    } else {
                        // Remove from pending uploads if successful (update case)
                        await MainActor.run {
                            localMembersToUpload.remove(tempId)
                        }
                    }
                } catch {
                    print("Failed to upload member immediately: \(error)")
                    // Will be retried during next sync
                }
            }
        }
        
        // Always call completion immediately for responsive UI
        completion()
    }

    func updateMember(_ member: Person, completion: @escaping () -> Void) {
        // Update local data immediately for transparent offline experience
        currentProject.members[member.id] = member
        
        // Cache the updated data
        cacheProjectData(project: currentProject, bills: currentProject.bills, members: currentProject.members)
        
        // Track for upload when online (only if it has a positive ID, meaning it exists on server)
        if member.id > 0 {
            localMembersToUpload.insert(member.id)
        }
        
        // Try to upload immediately if online, but don't block the UI
        Task {
            if !isOffline && member.id > 0 {
                do {
                    let _ = try await NetworkService.shared.uploadMember(member, to: currentProject)
                    // Remove from pending uploads if successful (this is always an update case)
                    await MainActor.run {
                        localMembersToUpload.remove(member.id)
                    }
                } catch {
                    print("Failed to upload member immediately: \(error)")
                    // Will be retried during next sync
                }
            }
        }
        
        // Always call completion immediately for responsive UI
        completion()
    }

    func deleteMember(_ member: Person, completion: @escaping () -> Void) {
        // Remove from local data immediately for transparent offline experience
        currentProject.members.removeValue(forKey: member.id)
        
        // Cache the updated data
        cacheProjectData(project: currentProject, bills: currentProject.bills, members: currentProject.members)
        
        // Track for deletion when online (only if it has a positive ID, meaning it exists on server)
        if member.id > 0 {
            localMembersToDelete.insert(member.id)
            // Remove from upload queue if it was there
            localMembersToUpload.remove(member.id)
        }
        
        // Try to delete immediately if online, but don't block the UI
        Task {
            if !isOffline && member.id > 0 {
                do {
                    try await NetworkService.shared.deleteMember(member.id, from: currentProject)
                    // Remove from pending deletions if successful
                    await MainActor.run {
                        localMembersToDelete.remove(member.id)
                    }
                } catch {
                    print("Failed to delete member immediately: \(error)")
                    // Will be retried during next sync
                }
            }
        }
        
        // Always call completion immediately for responsive UI
        completion()
    }

    func setCurrentProject(_ project: Project) {
        guard let project = projects.first(where: {
            $0 == project
        }) else {
            return
        }
        currentProject = project
        
        // Clear previous project's local change queues
        localBillsToUpload.removeAll()
        localMembersToUpload.removeAll()
        localBillsToDelete.removeAll()
        localMembersToDelete.removeAll()
        
        // Load last sync date from cache
        lastSyncDate = defaults.object(forKey: "lastSyncDate_\(project.id ?? 0)") as? Date
        
        loadBillsAndMembers()
        defaults.set(project.id, forKey: "projectID")
    }

    func updateProject(project: Project) {
        storageService.updateProject(project: project)
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        // Monitor app lifecycle to retry when app becomes active
        networkMonitorCancellable = NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { _ in
                if self.isOffline {
                    self.retryConnection()
                }
            }
    }
    
    func retryConnection() {
        loadBillsAndMembers()
    }
    
    // MARK: - Helper Methods
    
    private func updateBillMemberReferences(oldMemberId: Int, newMemberId: Int, updatedMember: Person) {
        // Update bills that reference this member as payer or ower
        for i in 0..<currentProject.bills.count {
            var bill = currentProject.bills[i]
            var needsUpdate = false
            
            // Update payer_id if it matches the old member ID
            if bill.payer_id == oldMemberId {
                bill.payer_id = newMemberId
                needsUpdate = true
            }
            
            // Update owers array if it contains the old member
            for j in 0..<bill.owers.count {
                if bill.owers[j].id == oldMemberId {
                    bill.owers[j] = updatedMember
                    needsUpdate = true
                }
            }
            
            if needsUpdate {
                currentProject.bills[i] = bill
                // Mark this bill for upload if it's not already queued
                if bill.id > 0 {
                    localBillsToUpload.insert(bill.id)
                }
            }
        }
    }
}

// MARK: - Cached Data Structure

struct CachedProjectData: Codable {
    let bills: [Bill]
    let members: [Int: Person]
    let cachedAt: Date
    let localBillsToUpload: Set<Int>
    let localMembersToUpload: Set<Int>
    let localBillsToDelete: Set<Int>
    let localMembersToDelete: Set<Int>
    
    init(bills: [Bill], members: [Int: Person], cachedAt: Date,
         localBillsToUpload: Set<Int> = [], localMembersToUpload: Set<Int> = [],
         localBillsToDelete: Set<Int> = [], localMembersToDelete: Set<Int> = []) {
        self.bills = bills
        self.members = members
        self.cachedAt = cachedAt
        self.localBillsToUpload = localBillsToUpload
        self.localMembersToUpload = localMembersToUpload
        self.localBillsToDelete = localBillsToDelete
        self.localMembersToDelete = localMembersToDelete
    }
}

// For backward compatibility with old cached data
struct OldCachedProjectData: Codable {
    let bills: [Bill]
    let members: [Int: Person]
    let cachedAt: Date
}
