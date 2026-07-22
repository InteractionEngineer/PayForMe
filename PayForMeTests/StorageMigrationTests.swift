//
//  StorageMigrationTests.swift
//  PayForMeTests
//

import GRDB
@testable import PayForMe
import XCTest

class StorageMigrationTests: XCTestCase {
    /*
     Test Notes: Projects added before V3 used the column "token" to store the project id.
     From V4: Projects store project id in column "project id" and use the column token to store a token used for authorization
     */
    func test_IHM_legacy_projects_migrate_token_to_project_id() throws {
        let dbQueue = try DatabaseQueue()
        let migrator = StorageService.makeMigrator()
        try migrator.migrate(dbQueue, upTo: "v3")

        try dbQueue.write { db in
            try db.execute(
                sql: "INSERT INTO storedProject (name, password, url, backend, token) VALUES (?, ?, ?, ?, ?)",
                arguments: ["Haushalt", "totally-secret", "https://ihatemoney.org", ProjectBackend.iHateMoney.rawValue, "haushalt-token"]
            )
        }

        try migrator.migrate(dbQueue)

        let projects = try dbQueue.read { db in
            try StoredProject.fetchAll(db)
        }
        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects[0].projectId, "haushalt-token")
        XCTAssertEqual(projects[0].name, "Haushalt")
    }
}
