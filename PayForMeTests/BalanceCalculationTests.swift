//
//  BalanceCalculationTests.swift
//  PayForMeTests
//
//  Tests for the balance calculation in BalanceViewModel.setBalances().
//
//  WHY THIS MATTERS:
//  The balance screen is the core feature users come to PayForMe for — it tells
//  them who owes whom how much. A bug here (wrong sign, wrong division, missed
//  bill) would cause users to make incorrect payments. We test with concrete
//  numbers that can be verified by hand.
//
//  HOW THE FORMULA WORKS:
//    balance(member) = total_paid_by_member - total_owed_by_member
//
//  "owed" for a given bill = bill.amount / bill.owers.count
//  (everyone in owers[] pays an equal share regardless of weight)
//
//  A positive balance means the person is owed money.
//  A negative balance means the person owes money.
//  The sum of all balances in a project is always zero.
//

import XCTest
@testable import PayForMe

class BalanceCalculationTests: XCTestCase {

    let alice = Person(id: 1, weight: 1, name: "Alice", activated: true)
    let bob   = Person(id: 2, weight: 1, name: "Bob",   activated: true)
    let carla = Person(id: 3, weight: 1, name: "Carla", activated: true)
    let testDate = DateFormatter.cospend.date(from: "2026-05-14")!

    // Creates an in-memory Project with the given members and bills.
    private func makeProject(members: [Person], bills: [Bill]) -> Project {
        let project = Project(
            name: "test", password: "pw", token: "tok",
            backend: .cospend, url: URL(string: "https://test.de")!,
            projectId: ""
        )
        project.members = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
        project.bills = bills
        return project
    }

    // Runs the exact same logic as BalanceViewModel.setBalances() and returns
    // a [memberId: balance] dictionary for easy assertion.
    private func calcBalances(for project: Project) -> [Int: Double] {
        let vm = BalanceViewModel()
        // Override the ProjectManager.shared project with our test project.
        // BalanceViewModel.currentProject is @Published var, so this is allowed.
        vm.currentProject = project
        vm.setBalances()
        return Dictionary(uniqueKeysWithValues: vm.balances.map { ($0.id, $0.amount) })
    }

    // Dictionary subscripts return Optional. This helper unwraps the value and
    // fails the test with a readable message if the member is missing entirely.
    private func bal(
        _ person: Person,
        in balances: [Int: Double],
        file: StaticString = #file,
        line: UInt = #line
    ) -> Double {
        guard let value = balances[person.id] else {
            XCTFail("No balance entry for '\(person.name)' (id \(person.id)) — " +
                    "is the member added to the project?", file: file, line: line)
            return 0.0
        }
        return value
    }

    private func makeBill(id: Int, amount: Double, payerId: Int, owers: [Person]) -> Bill {
        Bill(id: id, amount: amount, what: "Test", date: testDate,
             payer_id: payerId, owers: owers, repeat: "n")
    }

    // MARK: - Basic scenarios

    func testSimpleThreeWaySplit() {
        // Alice pays 30€ for all three. Each owes 10€.
        //   Alice:  paid 30, owes 10 → balance = +20
        //   Bob:    paid  0, owes 10 → balance = -10
        //   Carla:  paid  0, owes 10 → balance = -10
        let bill = makeBill(id: 1, amount: 30.0, payerId: alice.id,
                            owers: [alice, bob, carla])
        let balances = calcBalances(for: makeProject(members: [alice, bob, carla], bills: [bill]))

        XCTAssertEqual(bal(alice, in: balances), 20.0,  accuracy: 0.001)
        XCTAssertEqual(bal(bob,   in: balances), -10.0, accuracy: 0.001)
        XCTAssertEqual(bal(carla, in: balances), -10.0, accuracy: 0.001)
    }

    func testPayerNotListedAsOwer() {
        // Alice pays 20€ for Bob only (Alice has no obligation in this bill).
        //   Alice:  paid 20, owes  0 → balance = +20
        //   Bob:    paid  0, owes 20 → balance = -20
        let bill = makeBill(id: 1, amount: 20.0, payerId: alice.id, owers: [bob])
        let balances = calcBalances(for: makeProject(members: [alice, bob], bills: [bill]))

        XCTAssertEqual(bal(alice, in: balances),  20.0, accuracy: 0.001)
        XCTAssertEqual(bal(bob,   in: balances), -20.0, accuracy: 0.001)
    }

    func testMemberNotInvolvedInAnyBill() {
        // Carla is in the project but not in this bill.
        let bill = makeBill(id: 1, amount: 30.0, payerId: alice.id, owers: [alice, bob])
        let balances = calcBalances(for: makeProject(members: [alice, bob, carla], bills: [bill]))

        XCTAssertEqual(bal(carla, in: balances), 0.0, accuracy: 0.001,
                       "A member not in any bill must have a zero balance")
    }

    func testPayerAlsoOwes() {
        // Alice pays 10€ and is the only ower (e.g. she paid for herself).
        //   Alice:  paid 10, owes 10 → balance = 0
        let bill = makeBill(id: 1, amount: 10.0, payerId: alice.id, owers: [alice])
        let balances = calcBalances(for: makeProject(members: [alice], bills: [bill]))

        XCTAssertEqual(bal(alice, in: balances), 0.0, accuracy: 0.001)
    }

    // MARK: - Multiple bills

    func testMultipleBillsSamePayer() {
        // Alice pays two bills: 10€ and 20€, both split with Bob.
        // Total paid by Alice: 30€, total owed: 15€ → +15
        let bill1 = makeBill(id: 1, amount: 10.0, payerId: alice.id, owers: [alice, bob])
        let bill2 = makeBill(id: 2, amount: 20.0, payerId: alice.id, owers: [alice, bob])
        let balances = calcBalances(for: makeProject(members: [alice, bob], bills: [bill1, bill2]))

        XCTAssertEqual(bal(alice, in: balances),  15.0, accuracy: 0.001)
        XCTAssertEqual(bal(bob,   in: balances), -15.0, accuracy: 0.001)
    }

    func testMultipleBillsDifferentPayers() {
        // Bill 1: Alice pays 30€ for Alice, Bob, Carla (10€ each)
        // Bill 2: Bob pays 15€ for Bob, Carla (7.50€ each)
        //
        // Alice:  paid 30, owes 10           → balance = +20
        // Bob:    paid 15, owes (10 + 7.50)  → balance = -2.50
        // Carla:  paid  0, owes (10 + 7.50)  → balance = -17.50
        let bill1 = makeBill(id: 1, amount: 30.0, payerId: alice.id,
                             owers: [alice, bob, carla])
        let bill2 = makeBill(id: 2, amount: 15.0, payerId: bob.id,
                             owers: [bob, carla])
        let balances = calcBalances(for: makeProject(members: [alice, bob, carla],
                                                     bills: [bill1, bill2]))

        XCTAssertEqual(bal(alice, in: balances),  20.0, accuracy: 0.001)
        XCTAssertEqual(bal(bob,   in: balances),  -2.5, accuracy: 0.001)
        XCTAssertEqual(bal(carla, in: balances), -17.5, accuracy: 0.001)
    }

    // MARK: - Conservation law

    func testBalancesSumToZero_simpleSplit() {
        let bill = makeBill(id: 1, amount: 30.0, payerId: alice.id,
                            owers: [alice, bob, carla])
        let balances = calcBalances(for: makeProject(members: [alice, bob, carla], bills: [bill]))
        let total = balances.values.reduce(0.0, +)
        XCTAssertEqual(total, 0.0, accuracy: 0.001,
                       "Conservation law: the sum of all balances must always be zero")
    }

    func testBalancesSumToZero_complexScenario() {
        let bill1 = makeBill(id: 1, amount: 30.0, payerId: alice.id,
                             owers: [alice, bob, carla])
        let bill2 = makeBill(id: 2, amount: 15.0, payerId: bob.id,
                             owers: [bob, carla])
        let bill3 = makeBill(id: 3, amount: 9.0,  payerId: carla.id,
                             owers: [alice, carla])
        let project = makeProject(members: [alice, bob, carla],
                                  bills: [bill1, bill2, bill3])
        let total = calcBalances(for: project).values.reduce(0.0, +)
        XCTAssertEqual(total, 0.0, accuracy: 0.001)
    }

    // MARK: - Edge cases

    func testNoBills_allBalancesAreZero() {
        let balances = calcBalances(for: makeProject(members: [alice, bob], bills: []))
        XCTAssertEqual(bal(alice, in: balances), 0.0, accuracy: 0.001)
        XCTAssertEqual(bal(bob,   in: balances), 0.0, accuracy: 0.001)
    }

    func testNoMembers_noBalances() {
        let balances = calcBalances(for: makeProject(members: [], bills: []))
        XCTAssertTrue(balances.isEmpty)
    }

    func testFractionalAmounts() {
        // 10€ split three ways → 3.333...€ each. The balance must handle floats.
        let bill = makeBill(id: 1, amount: 10.0, payerId: alice.id,
                            owers: [alice, bob, carla])
        let balances = calcBalances(for: makeProject(members: [alice, bob, carla], bills: [bill]))

        let expected = 10.0 / 3.0
        XCTAssertEqual(bal(alice, in: balances), 10.0 - expected, accuracy: 0.001)
        XCTAssertEqual(bal(bob,   in: balances), -expected,       accuracy: 0.001)
        XCTAssertEqual(bal(carla, in: balances), -expected,       accuracy: 0.001)
    }
}
