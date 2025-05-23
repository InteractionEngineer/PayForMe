//
//  StorageService.swift
//  PayForMe
//
//  Created by Max Tharr on 22.01.20.
//

import Foundation
import GRDB

class StorageService {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    private let databasePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private var legacyFilePath: URL {
        return databasePath.appendingPathComponent("Projects.json")
    }

    private let dbQueue: DatabaseQueue

    init() {
        do {
            var migrator = DatabaseMigrator()

            migrator.registerMigration("v1", migrate: { db in
                try db.create(table: "storedProject", ifNotExists: true) { table in
                    table.autoIncrementedPrimaryKey("id")
                    table.column("name")
                    table.column("password")
                    table.column("url")
                    table.column("backend")
                }
            })
            migrator.registerMigration("v2", migrate: { db in
                try db.alter(table: "storedProject", body: { table in
                    table.add(column: "token")
                })
                try db.execute(sql: "UPDATE storedProject SET token = name;")

            })
            migrator.registerMigration("v3") { db in
                try db.alter(table: "storedProject", body: { table in
                    table.add(column: "me")
                })
            }
            // #if DEBUG
            //// Speed up development by nuking the database when migrations change
            // migrator.eraseDatabaseOnSchemaChange = true
            // #endif
            dbQueue = try DatabaseQueue(path: databasePath.appendingPathComponent("payforme.sqlite").path)
            try migrator.migrate(dbQueue)
        } catch {
            print("Storage couldn't be initialized \(error.localizedDescription)")
            fatalError()
        }
        #if targetEnvironment(simulator)
            print("Database file at \(databasePath.appendingPathComponent("payforme.sqlite").path)")
        #endif
        testLegacy()
        print("Storage service initialized")
    }

    func saveProject(project: Project) -> Bool {
        let storedProject = StoredProject(project: project)
        do {
            return try dbQueue.write { db -> Bool in
                if try !StoredProject.fetchAll(db).contains(storedProject) {
                    try storedProject.save(db)
                    return true
                }
                return false
            }
        } catch {
            print("Couldn't store projects \(error.localizedDescription)")
            return false
        }
    }

    func updateProject(project: Project) {
        let storedProject = StoredProject(project: project)
        do {
            _ = try dbQueue.write { db -> Bool in
                if try StoredProject.fetchAll(db).contains(storedProject) {
                    try storedProject.save(db)
                    return true
                }
                return false
            }
        } catch {
            print("Couldn't updates projects \(error.localizedDescription)")
        }
    }

    func loadProjects() -> [Project] {
        do {
            return try dbQueue.read { db in
                try StoredProject.fetchAll(db).map { $0.toProject() }
            }
        } catch {
            print("Catched \(error.localizedDescription) while loading projects")
            return []
        }
    }

    func removeProject(project: Project) {
        let storedProject = StoredProject(project: project)
        do {
            try dbQueue.write { db in
                try storedProject.delete(db)
            }
        } catch {
            print("Couldn't remove projects \(error.localizedDescription)")
        }
    }

    private func testLegacy() {
        guard let data = try? Data(contentsOf: legacyFilePath) else {
            return
        }
        print("Found old file URL")
        do {
            let projects = try decoder.decode([OldProject].self, from: data)
            storeProjects(projects: projects.map { $0.toProject() })
            try FileManager.default.removeItem(at: legacyFilePath)
            print("data loaded legacy, will save as new")
        } catch {
            print("\(error.localizedDescription)")
        }
    }

    private func storeProjects(projects: [StoredProject]) {
        do {
            try dbQueue.write { db in
                try projects.forEach { try $0.save(db) }
            }
        } catch {
            print("Couldn't store projects \(error.localizedDescription)")
        }
    }
}

extension StoredProject: FetchableRecord, PersistableRecord {}

private class OldProject: Codable, Identifiable {
    let name: String
    let password: String
    let url: URL
    let id: UUID
    let backend: ProjectBackend

    var members: [Int: Person]
    var bills: [Bill]

    func toProject() -> StoredProject {
        return StoredProject(name: name, password: password, token: name, url: url, backend: backend)
    }
}
