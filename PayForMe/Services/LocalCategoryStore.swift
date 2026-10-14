//
//  LocalCategoryStore.swift
//  PayForMe
//

import Foundation
import GRDB

/// Bill categories kept on this device only, for servers that have no category field of their
/// own (stock iHateMoney). Keyed by project and bill id; nothing here is synced.
final class LocalCategoryStore {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    /// Server URL + project id: stable across app restarts, unlike the database row id which is
    /// reassigned when a project is removed and added again.
    static func key(for project: Project) -> String {
        "\(project.url.absoluteString)|\(project.projectId)"
    }

    /// bill id → category id
    func categories(projectKey: String) -> [Int: Int] {
        do {
            return try dbQueue.read { db in
                let rows = try Row.fetchAll(db, sql: "SELECT billId, categoryId FROM localBillCategory WHERE projectKey = ?", arguments: [projectKey])
                return Dictionary(rows.map { ($0["billId"] as Int, $0["categoryId"] as Int) }) { _, last in last }
            }
        } catch {
            print("Couldn't read local categories \(error.localizedDescription)")
            return [:]
        }
    }

    /// 0 means "no category" and clears the entry, like the server APIs encode it.
    func set(categoryId: Int, billId: Int, projectKey: String) {
        do {
            try dbQueue.write { db in
                if categoryId == 0 {
                    try db.execute(sql: "DELETE FROM localBillCategory WHERE projectKey = ? AND billId = ?", arguments: [projectKey, billId])
                } else {
                    try db.execute(sql: "INSERT OR REPLACE INTO localBillCategory (projectKey, billId, categoryId) VALUES (?, ?, ?)", arguments: [projectKey, billId, categoryId])
                }
            }
        } catch {
            print("Couldn't store local category \(error.localizedDescription)")
        }
    }

    func remove(billId: Int, projectKey: String) {
        set(categoryId: 0, billId: billId, projectKey: projectKey)
    }
}
