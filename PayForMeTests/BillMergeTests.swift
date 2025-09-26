import XCTest
@testable import PayForMe

public class BillMergeTests: XCTestCase {
    public func testMergeBills_DuplicateDetection() {
        let now = Date()
        let person1 = Person(id: 1, weight: 1, name: "A", activated: true)
        let person2 = Person(id: 2, weight: 1, name: "B", activated: true)
        let owers1 = [person1, person2]
        let owers2 = [person2, person1] // different order
        let localBill = Bill(id: -1, amount: 10.0, what: "Lunch", date: now, payer_id: 1, owers: owers1, repeat: nil, lastchanged: nil)
        let serverBill = Bill(id: 100, amount: 10.0, what: "Lunch", date: now, payer_id: 1, owers: owers2, repeat: nil, lastchanged: nil)
        let pm = ProjectManager.shared
        let merged = pm.performMergeBillsTest(local: [localBill], server: [serverBill])
        // Only the server bill should remain
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].id, 100)
    }
    public func testMergeBills_DifferentAmount() {
        let now = Date()
        let person1 = Person(id: 1, weight: 1, name: "A", activated: true)
        let person2 = Person(id: 2, weight: 1, name: "B", activated: true)
        let owers = [person1, person2]
        let localBill = Bill(id: -1, amount: 10.0, what: "Lunch", date: now, payer_id: 1, owers: owers, repeat: nil, lastchanged: nil)
        let serverBill = Bill(id: 100, amount: 11.0, what: "Lunch", date: now, payer_id: 1, owers: owers, repeat: nil, lastchanged: nil)
        let pm = ProjectManager.shared
        let merged = pm.performMergeBillsTest(local: [localBill], server: [serverBill])
        // Both bills should remain
        XCTAssertEqual(merged.count, 2)
    }
}
