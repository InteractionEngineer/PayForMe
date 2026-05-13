//
//  BillSortingTests.swift
//  PayForMeTests
//
//  Tests for BillListViewModel.SortedBy — the two sort modes available in the
//  Bills tab.
//
//  WHY THIS MATTERS:
//  Users rely on the bill list to find their most recent expenses. An incorrect
//  sort order means they see old bills at the top and miss new ones. This is
//  especially important when multiple people add bills from different devices,
//  because the `lastchanged` timestamp (set by the server) differs from the
//  expense date the user chose.
//

import XCTest
@testable import PayForMe

class BillSortingTests: XCTestCase {

    private let base = DateFormatter.cospend.date(from: "2026-01-01")!

    private func date(addingDays days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: base)!
    }

    private func makeBill(id: Int, daysOffset: Int, lastchanged: Int?) -> Bill {
        Bill(
            id: id,
            amount: 10.0,
            what: "Bill \(id)",
            date: date(addingDays: daysOffset),
            payer_id: 1,
            owers: [],
            repeat: "n",
            lastchanged: lastchanged
        )
    }

    // MARK: - Sort by expense date

    func testExpenseDate_sortedNewestFirst() {
        // Bills are sorted so the most recent *expense date* is at index 0.
        let bills = [
            makeBill(id: 1, daysOffset: 0, lastchanged: nil),  // Jan 1
            makeBill(id: 2, daysOffset: 5, lastchanged: nil),  // Jan 6
            makeBill(id: 3, daysOffset: 2, lastchanged: nil),  // Jan 3
        ]
        let sorted = BillListViewModel.SortedBy.expenseDate.sort(bills: bills)
        XCTAssertEqual(sorted.map { $0.id }, [2, 3, 1])
    }

    func testExpenseDate_preservesBothBillsOnTie() {
        // Two bills on the same date must both appear (no de-duplication).
        let bills = [
            makeBill(id: 1, daysOffset: 0, lastchanged: nil),
            makeBill(id: 2, daysOffset: 0, lastchanged: nil),
        ]
        let sorted = BillListViewModel.SortedBy.expenseDate.sort(bills: bills)
        XCTAssertEqual(sorted.count, 2)
    }

    func testExpenseDate_singleBill() {
        let bills = [makeBill(id: 1, daysOffset: 0, lastchanged: nil)]
        let sorted = BillListViewModel.SortedBy.expenseDate.sort(bills: bills)
        XCTAssertEqual(sorted.map { $0.id }, [1])
    }

    func testExpenseDate_emptyList() {
        let sorted = BillListViewModel.SortedBy.expenseDate.sort(bills: [])
        XCTAssertTrue(sorted.isEmpty)
    }

    func testExpenseDate_alreadySorted() {
        let bills = [
            makeBill(id: 3, daysOffset: 4, lastchanged: nil),
            makeBill(id: 2, daysOffset: 2, lastchanged: nil),
            makeBill(id: 1, daysOffset: 0, lastchanged: nil),
        ]
        let sorted = BillListViewModel.SortedBy.expenseDate.sort(bills: bills)
        XCTAssertEqual(sorted.map { $0.id }, [3, 2, 1])
    }

    func testExpenseDate_reverseOrder() {
        let bills = [
            makeBill(id: 1, daysOffset: 0, lastchanged: nil),
            makeBill(id: 2, daysOffset: 2, lastchanged: nil),
            makeBill(id: 3, daysOffset: 4, lastchanged: nil),
        ]
        let sorted = BillListViewModel.SortedBy.expenseDate.sort(bills: bills)
        XCTAssertEqual(sorted.map { $0.id }, [3, 2, 1])
    }

    // MARK: - Sort by changed date

    func testChangedDate_sortedMostRecentFirst() {
        // `lastchanged` is a Unix timestamp set by the server whenever a bill
        // is created or edited. A higher value means more recently changed.
        let bills = [
            makeBill(id: 1, daysOffset: 0, lastchanged: 100),
            makeBill(id: 2, daysOffset: 0, lastchanged: 300),
            makeBill(id: 3, daysOffset: 0, lastchanged: 200),
        ]
        let sorted = BillListViewModel.SortedBy.changedDate.sort(bills: bills)
        XCTAssertEqual(sorted.map { $0.id }, [2, 3, 1])
    }

    func testChangedDate_nilTreatedAsZero() {
        // Bills without a lastchanged value (older Cospend format) are treated
        // as if they were last changed at Unix epoch (i.e. a long time ago).
        // They should appear after any bill that has a real timestamp.
        let bills = [
            makeBill(id: 1, daysOffset: 0, lastchanged: nil),  // → 0
            makeBill(id: 2, daysOffset: 0, lastchanged: 1),    // → 1
        ]
        let sorted = BillListViewModel.SortedBy.changedDate.sort(bills: bills)
        XCTAssertEqual(sorted.map { $0.id }, [2, 1])
    }

    func testChangedDate_allNilDoesNotCrash() {
        // If no bills have lastchanged (e.g. all came from an old server), the sort
        // must still complete without crashing or dropping bills.
        let bills = [
            makeBill(id: 1, daysOffset: 0, lastchanged: nil),
            makeBill(id: 2, daysOffset: 0, lastchanged: nil),
            makeBill(id: 3, daysOffset: 0, lastchanged: nil),
        ]
        let sorted = BillListViewModel.SortedBy.changedDate.sort(bills: bills)
        XCTAssertEqual(sorted.count, 3, "All nil lastchanged must not crash or drop bills")
    }

    func testChangedDate_preservesBothBillsOnTie() {
        let bills = [
            makeBill(id: 1, daysOffset: 0, lastchanged: 500),
            makeBill(id: 2, daysOffset: 0, lastchanged: 500),
        ]
        let sorted = BillListViewModel.SortedBy.changedDate.sort(bills: bills)
        XCTAssertEqual(sorted.count, 2)
    }

    // MARK: - Mixed scenarios

    func testChangedDate_mixedNilAndReal() {
        // Real timestamps must always sort before nil (which becomes 0).
        let bills = [
            makeBill(id: 1, daysOffset: 0, lastchanged: nil),
            makeBill(id: 2, daysOffset: 0, lastchanged: 1000),
            makeBill(id: 3, daysOffset: 0, lastchanged: nil),
            makeBill(id: 4, daysOffset: 0, lastchanged: 500),
        ]
        let sorted = BillListViewModel.SortedBy.changedDate.sort(bills: bills)
        XCTAssertEqual(sorted.first?.id, 2, "Highest lastchanged must be first")
        XCTAssertEqual(sorted[1].id, 4)
    }

    func testExpenseDate_ignoresLastchanged() {
        // When sorting by expense date the lastchanged field must be ignored.
        // Bill 1 has lastchanged = 999 (high) but an older expense date — it must
        // still sort after bill 2.
        let bills = [
            makeBill(id: 1, daysOffset: 0, lastchanged: 999),  // Jan 1, changed late
            makeBill(id: 2, daysOffset: 5, lastchanged: 1),    // Jan 6, changed early
        ]
        let sorted = BillListViewModel.SortedBy.expenseDate.sort(bills: bills)
        XCTAssertEqual(sorted.map { $0.id }, [2, 1],
                       "Expense-date sort must ignore lastchanged")
    }
}
