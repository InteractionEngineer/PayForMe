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

    @Published
    private(set) var projects = [Project]()

    @Published
    var currentProject: Project = demoProject

    let storageService = StorageService()

    static let shared = ProjectManager()

    @Published var openedByURL: URL?

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
        let project = currentProject

        let billsPublisher = NetworkService.shared.loadBillsPublisher(project)
        let membersPublisher = NetworkService.shared.loadMembersPublisher(project)

        Publishers.Zip(billsPublisher, membersPublisher)
            .map { bills, members in
                project.bills = bills
                project.members = members
                return project
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentProject)
    }

    private func updateBill(bill: Bill) async {
        do {
            try await NetworkService.shared.update(bill: bill)
        } catch {
            // TODO
            print("Error posting bill")
            
        }
    }

    private func createBill(bill: Bill) async {
        do {
            try await NetworkService.shared.post(bill: bill)
        } catch {
            // TODO
            print("Error posting bill")
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

    func saveBill(_ bill: Bill) async {
        if bill.id != -1 && self.currentProject.bills.contains(where: {
            $0.id == bill.id
        }) {
            await createBill(bill: bill)
        } else {
            await updateBill(bill: bill)
        }
    }

    func deleteBill(_ bill: Bill, completion: @escaping () -> Void) {
        currentProject.bills.removeAll {
            $0.id == bill.id
        }
        deleteBillFromServer(bill: bill, completion: completion)
    }

    func addMember(_ name: String, completion: @escaping () -> Void) {
        let newMember = Person(id: -1, weight: -1, name: name, activated: true, color: nil)
        sendMemberToServer(newMember, update: false, completion: completion)
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
        currentProject = project
        loadBillsAndMembers()
        defaults.set(project.id, forKey: "projectID")
    }

    func updateProject(project: Project) {
        storageService.updateProject(project: project)
    }
}
