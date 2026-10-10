//
//  Project.swift
//  PayForMe
//
//  Created by Max Tharr on 23.01.20.
//

import Foundation

class Project: Codable, Identifiable {
    let name: String
    let password: String
    let token: String
    let url: URL
    let id: Int?
    let backend: ProjectBackend

    var members: [Int: Person]
    var bills: [Bill]
    var categories: [CospendTag]
    var paymentModes: [CospendTag]
    var me: Int?

    let projectId: String

    convenience init(name: String, password: String, token: String, backend: ProjectBackend, url: URL, projectId: String) {
        self.init(name: name, password: password, token: token, backend: backend, url: url, id: nil, projectId: projectId)
    }

    fileprivate init(name: String, password: String, token: String, backend: ProjectBackend, url: URL, id: Int?, me: Int? = nil, projectId: String, categories: [CospendTag] = [], paymentModes: [CospendTag] = []) {
        self.name = name
        self.password = password
        self.token = token
        self.backend = backend
        self.url = url
        self.id = id
        self.members = [:]
        self.bills = []
        self.categories = categories
        self.paymentModes = paymentModes
        self.me = me
        self.projectId = projectId
    }
}

struct APIProject: Codable {
    let name: String
    let id: String
}

struct StoredProject: Codable {
    let name: String
    let password: String
    let token: String
    let url: URL
    let backend: ProjectBackend
    var id: Int?
    let me: Int?
    let projectId: String

    init(name: String, password: String, token: String, url: URL, backend: ProjectBackend, projectId: String) {
        self.name = name
        self.password = password
        self.token = token
        self.url = url
        self.backend = backend
        id = nil
        me = nil
        self.projectId = projectId
    }

    init(project: Project) {
        name = project.name
        password = project.password
        token = project.token
        url = project.url
        backend = project.backend
        id = project.id
        me = project.me
        projectId = project.projectId
    }

    func toProject() -> Project {
        Project(name: name, password: password, token: token, backend: backend, url: url, id: id!, me: me, projectId: projectId)
    }
}

extension Project {
    func category(for bill: Bill) -> CospendTag? {
        tag(id: bill.categoryid, in: categories)
    }

    func paymentMode(for bill: Bill) -> CospendTag? {
        tag(id: bill.paymentmodeid, in: paymentModes)
    }

    private func tag(id: Int?, in tags: [CospendTag]) -> CospendTag? {
        guard let id = id, id != 0 else { return nil }
        return tags.first { $0.id == id }
    }

    func listedCategoryId(_ id: Int) -> Int { listedId(id, in: categories) }

    func listedPaymentModeId(_ id: Int) -> Int { listedId(id, in: paymentModes) }

    private func listedId(_ id: Int, in tags: [CospendTag]) -> Int {
        tags.contains { $0.id == id } ? id : 0
    }
}

extension Project: Equatable {
    static func == (lhs: Project, rhs: Project) -> Bool {
        return lhs.url == rhs.url && lhs.name == rhs.name && lhs.backend == rhs.backend && lhs.password == rhs.password
    }
}

extension StoredProject: Equatable {
    static func == (lhs: StoredProject, rhs: StoredProject) -> Bool {
        return lhs.url == rhs.url && lhs.name == rhs.name && lhs.token == rhs.token && lhs.backend == rhs.backend && lhs.password == rhs.password
    }
}

enum ProjectBackend: Int, Codable {
    case cospend = 0
    case iHateMoney = 1

    var staticPath: String {
        switch self {
        case .cospend:
            return "index.php/apps/cospend/api/projects"
        case .iHateMoney:
            return "api/projects"
        }
    }
}

let previewProject = Project(
    name: "TestProject",
    password: "TestPassword",
    token: "asdasdas",
    backend: .cospend,
    url: URL(string: "https://testserver.de")!,
    id: 0,
    projectId: "TestProject",
    categories: [CospendTag(id: 0, name: "Food", color: "FFFEEE", icon: "", order: 0)],
    paymentModes: [CospendTag(id: 0, name: "Cash", color: "010010", icon: "", order: 0)]
)
let previewProjects = [
    previewProject,
    Project(name: "test1", password: "test23", token: "dasdasa", backend: .cospend, url: URL(string: "https://testserver.de")!, id: 1, projectId: "test1"),
    Project(name: "test2", password: "test45", token: "123123122", backend: .cospend, url: URL(string: "https://testserver.de")!, id: 2, projectId: "test2"),
]
let demoProject = Project(name: "study-group", password: "no-pass", token: "9da50e410157dc1ca63e594af022f3a2", backend: .cospend, url: URL(string: "https://intranet.mayflower.de")!, id: 1, projectId: "study-group")
