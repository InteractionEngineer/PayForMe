//
//  DataManager.swift
//  PayForMe
//
//  Created by Camille Mainz on 04.02.20.
//

import Combine
import Foundation

class ProjectManager: ObservableObject {
    private let defaults = UserDefaults.standard

    private var cancellable: Cancellable?
    private var loadCancellable: AnyCancellable?

    @Published
    private(set) var projects = [Project]()

    @Published
    var currentProject: Project = demoProject

    let storageService = StorageService()

    static let shared = ProjectManager()

    @Published var openedByURL: URL?

    /// The last failure while loading bills and members, or nil after a load
    /// that worked. Set so the UI can say something instead of showing lists
    /// that are empty for no visible reason (#37).
    @Published var loadingError: LoadError?

    private init() {
        print("init")
        projects = storageService.loadProjects()

        let id = defaults.integer(forKey: "projectID")
        if let project = projects.first(where: {
            $0.id == id
        }) {
            currentProject = project
            loadBillsAndMembers()
        } else {
            if !projects.isEmpty {
                currentProject = projects[0]
            }
        }
    }

    func openedByURL(url: URL) {
        guard url.decodeCospendString() != nil || url.decodeIHateMoneyString() != nil else { return }
        openedByURL = url
    }

    // MARK: Server Communication

    func refresh() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            loadBillsAndMembers {
                continuation.resume()
            }
        }
    }

    func loadBillsAndMembers(completion: (() -> Void)? = nil) {
        let project = currentProject

        let billsPublisher = NetworkService.shared.loadBillsPublisher(project)
        let membersPublisher = NetworkService.shared.loadMembersPublisher(project)

        var completionInvoked = false
        let invokeCompletionOnce: () -> Void = {
            guard !completionInvoked else { return }
            completionInvoked = true
            completion?()
        }

        loadCancellable = Publishers.Zip(billsPublisher, membersPublisher)
            .map { bills, members in
                project.bills = bills
                project.members = members
                return project
            }
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveCancel: invokeCompletionOnce)
            .sink(
                receiveCompletion: { [weak self] result in
                    if case let .failure(error) = result {
                        self?.loadingError = error
                    }
                    invokeCompletionOnce()
                },
                receiveValue: { [weak self] project in
                    // A load that worked clears whatever went wrong last time.
                    self?.loadingError = nil
                    self?.currentProject = project
                    invokeCompletionOnce()
                }
            )
    }

    private func sendBillToServer(bill: Bill, update: Bool, completion: @escaping () -> Void) {
        cancellable?.cancel()
        cancellable = nil

        if update {
            cancellable = NetworkService.shared.updateBillPublisher(bill: bill)
                .receive(on: DispatchQueue.main)
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
                .receive(on: DispatchQueue.main)
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
            .receive(on: DispatchQueue.main)
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
                .receive(on: DispatchQueue.main)
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
                .receive(on: DispatchQueue.main)
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
            .receive(on: DispatchQueue.main)
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
        let didSave = storageService.saveProject(project: project)
        let reloaded = storageService.loadProjects()

        // An already-existing project is not an error: it just gets activated (same for manual add
        // and QR scan). Only a real save failure throws.
        guard didSave || reloaded.contains(project) else {
            throw StoringError.couldNotSave
        }
        DispatchQueue.main.async { [self] in
            projects = reloaded

            // Always activate the added (or already-known) project, whether it's the first or not.
            setCurrentProject(project)
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
        if bill.id != -1, let _ = currentProject.bills.firstIndex(where: {
            $0.id == bill.id
        }) {
            sendBillToServer(bill: bill, update: true, completion: completion)
        } else {
            sendBillToServer(bill: bill, update: false, completion: completion)
        }
    }

    func deleteBill(_ bill: Bill, completion: @escaping () -> Void) {
        currentProject.bills.removeAll {
            $0.id == bill.id
        }
        deleteBillFromServer(bill: bill, completion: completion)
    }

    /// Creates a member and reports the HTTP status code (2xx = success, -1 = transport error) so the UI can surface a real error.
    func addMember(_ name: String, completion: @escaping (Int) -> Void) {
        cancellable?.cancel()
        cancellable = NetworkService.shared.createMemberStatusPublisher(name: name)
            .receive(on: DispatchQueue.main)
            .sink { statusCode in
                if (200 ... 299).contains(statusCode) {
                    print("Member successfully created")
                } else {
                    print("Error creating member: HTTP \(statusCode)")
                }
                completion(statusCode)
            }
    }

    func updateMember(_ member: Person, completion: @escaping () -> Void) {
        sendMemberToServer(member, update: true, completion: completion)
    }

    func deleteMember(_ member: Person, completion: @escaping () -> Void) {
        deleteMemberFromServer(member, completion: completion)
    }

    func setCurrentProject(_ project: Project) {
        guard let project = projects.first(where: {
            $0 == project
        }) else {
            return
        }
        loadCancellable?.cancel()
        currentProject = project
        loadBillsAndMembers()
        defaults.set(project.id, forKey: "projectID")
    }

    func updateProject(project: Project) {
        storageService.updateProject(project: project)
    }
}
