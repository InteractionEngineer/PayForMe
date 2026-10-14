//
//  LocalCategoryStoreTests.swift
//  PayForMeTests
//
//  Categories kept on the device for servers without a category field.
//

import GRDB
import XCTest
@testable import PayForMe

class LocalCategoryStoreTests: XCTestCase {
    private func makeStore() throws -> LocalCategoryStore {
        let dbQueue = try DatabaseQueue()
        try StorageService.makeMigrator().migrate(dbQueue)
        return LocalCategoryStore(dbQueue: dbQueue)
    }

    func testSetAndRead() throws {
        let store = try makeStore()
        store.set(categoryId: -1, billId: 5, projectKey: "a")
        store.set(categoryId: -12, billId: 6, projectKey: "a")
        XCTAssertEqual(store.categories(projectKey: "a"), [5: -1, 6: -12])
    }

    func testSetReplacesExistingEntry() throws {
        let store = try makeStore()
        store.set(categoryId: -1, billId: 5, projectKey: "a")
        store.set(categoryId: -3, billId: 5, projectKey: "a")
        XCTAssertEqual(store.categories(projectKey: "a"), [5: -3])
    }

    func testZeroClearsTheEntry() throws {
        let store = try makeStore()
        store.set(categoryId: -1, billId: 5, projectKey: "a")
        store.set(categoryId: 0, billId: 5, projectKey: "a")
        XCTAssertTrue(store.categories(projectKey: "a").isEmpty)
    }

    func testProjectsAreSeparate() throws {
        let store = try makeStore()
        store.set(categoryId: -1, billId: 5, projectKey: "a")
        store.set(categoryId: -2, billId: 5, projectKey: "b")
        XCTAssertEqual(store.categories(projectKey: "a"), [5: -1])
        XCTAssertEqual(store.categories(projectKey: "b"), [5: -2])
    }

    func testRemove() throws {
        let store = try makeStore()
        store.set(categoryId: -1, billId: 5, projectKey: "a")
        store.remove(billId: 5, projectKey: "a")
        XCTAssertTrue(store.categories(projectKey: "a").isEmpty)
    }

    func testKeyCombinesServerAndProjectId() {
        let project = Project.makeIHateMoney(url: "https://ihatemoney.org", projectId: "trip")
        XCTAssertEqual(LocalCategoryStore.key(for: project), "https://ihatemoney.org|trip")
    }
}
