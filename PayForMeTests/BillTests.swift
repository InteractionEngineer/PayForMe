//
//  BillTests.swift
//  PayForMeTests
//
//  Tests for Bill.paramsFor(_:) — the single function that translates a Bill
//  into the HTTP request parameters sent to the backend.
//
//  WHY THIS MATTERS:
//  Cospend and iHateMoney have different API contracts for the same concept:
//    • Cospend expects payed_for as a comma-separated String: "1,2,3"
//    • iHateMoney expects payed_for as a JSON Array: ["1", "2", "3"]
//  Getting this wrong silently causes bills to be saved without owers on one
//  backend or the other, which is a data-loss bug that users would only notice
//  when they check balances later. These tests act as a regression net.
//

import XCTest
@testable import PayForMe

class BillTests: XCTestCase {

    // A fixed date so our date-formatting tests are deterministic
    let testDate = DateFormatter.cospend.date(from: "2026-05-14")!

    func makeBill(
        amount: Double = 30.0,
        owers: [Person] = [testAlice, testBob, testCarla],
        repeat repeatValue: String? = "n"
    ) -> Bill {
        Bill(
            id: 42,
            amount: amount,
            what: "Dinner",
            date: testDate,
            payer_id: testAlice.id,
            owers: owers,
            repeat: repeatValue,
            lastchanged: nil
        )
    }

    // MARK: - Cospend parameters

    func testCospend_payedFor_isCommaSeparatedString() {
        // Cospend's API endpoint for creating a bill reads payed_for as a
        // plain query-string value, so it must be a single comma-separated string.
        let params = makeBill(owers: [testAlice, testBob, testCarla]).paramsFor(.cospend)

        guard let payedFor = params["payed_for"] as? String else {
            return XCTFail("payed_for must be a String for Cospend, got \(type(of: params["payed_for"]))")
        }
        let ids = Set(payedFor.split(separator: ",").map(String.init))
        XCTAssertEqual(ids, Set(["1", "2", "3"]))
    }

    func testCospend_payedFor_singleOwer() {
        let params = makeBill(owers: [testBob]).paramsFor(.cospend)
        XCTAssertEqual(params["payed_for"] as? String, "2")
    }

    func testCospend_paymentMode_isN() {
        // The Cospend API requires paymentmode; "n" means "no specific payment mode".
        let params = makeBill().paramsFor(.cospend)
        XCTAssertEqual(params["paymentmode"] as? String, "n")
    }

    func testCospend_categoryId_isZero() {
        // "0" is the default uncategorised category in Cospend.
        let params = makeBill().paramsFor(.cospend)
        XCTAssertEqual(params["categoryid"] as? String, "0")
    }

    func testCospend_repeat_defaultsToN() {
        let params = makeBill(repeat: "n").paramsFor(.cospend)
        XCTAssertEqual(params["repeat"] as? String, "n")
    }

    func testCospend_repeat_customValue() {
        // Cospend supports recurring bills (e.g. "d"=daily, "w"=weekly).
        let params = makeBill(repeat: "d").paramsFor(.cospend)
        XCTAssertEqual(params["repeat"] as? String, "d")
    }

    func testCospend_repeat_nilFallsBackToN() {
        // If the Bill was created without a repeat value (e.g. from iHateMoney),
        // paramsFor must still send "n" to Cospend — never omit the field.
        let params = makeBill(repeat: nil).paramsFor(.cospend)
        XCTAssertEqual(params["repeat"] as? String, "n")
    }

    func testCospend_date_isFormattedYYYYMMDD() {
        // Cospend uses yyyy-MM-dd format. A wrong format would cause a server-side
        // parse error and silently reject the bill.
        let params = makeBill().paramsFor(.cospend)
        XCTAssertEqual(params["date"] as? String, "2026-05-14")
    }

    func testCospend_payer_isStringNotInt() {
        // The params dict is [String: Any]. payer must be a String because it is
        // appended to a query string; sending an Int would type-mismatch on the server.
        let params = makeBill().paramsFor(.cospend)
        XCTAssertEqual(params["payer"] as? String, "1")
    }

    func testCospend_amount_isStringRepresentation() {
        let params = makeBill(amount: 42.5).paramsFor(.cospend)
        XCTAssertEqual(params["amount"] as? String, "42.5")
    }

    func testCospend_what_isPresent() {
        let params = makeBill().paramsFor(.cospend)
        XCTAssertEqual(params["what"] as? String, "Dinner")
    }

    // MARK: - iHateMoney parameters

    func testIHateMoney_payedFor_isStringArray() {
        // iHateMoney's JSON API expects payed_for as a JSON array of ID strings.
        // Sending a comma-separated string would cause a 400 Bad Request.
        let params = makeBill(owers: [testAlice, testBob, testCarla]).paramsFor(.iHateMoney)

        guard let payedFor = params["payed_for"] as? [String] else {
            return XCTFail("payed_for must be [String] for iHateMoney, got \(type(of: params["payed_for"]))")
        }
        XCTAssertEqual(Set(payedFor), Set(["1", "2", "3"]))
    }

    func testIHateMoney_payedFor_singleOwer() {
        let params = makeBill(owers: [testBob]).paramsFor(.iHateMoney)
        XCTAssertEqual(params["payed_for"] as? [String], ["2"])
    }

    func testIHateMoney_noPaymentMode() {
        // iHateMoney does not have a paymentmode concept; sending it would be ignored
        // at best and cause an error at worst.
        let params = makeBill().paramsFor(.iHateMoney)
        XCTAssertNil(params["paymentmode"],
                     "iHateMoney must NOT receive paymentmode")
    }

    func testIHateMoney_noCategoryId() {
        let params = makeBill().paramsFor(.iHateMoney)
        XCTAssertNil(params["categoryid"],
                     "iHateMoney must NOT receive categoryid")
    }

    func testIHateMoney_noRepeat() {
        let params = makeBill().paramsFor(.iHateMoney)
        XCTAssertNil(params["repeat"],
                     "iHateMoney must NOT receive repeat")
    }

    func testIHateMoney_date_isFormattedYYYYMMDD() {
        let params = makeBill().paramsFor(.iHateMoney)
        XCTAssertEqual(params["date"] as? String, "2026-05-14")
    }

    func testIHateMoney_payer_isString() {
        let params = makeBill().paramsFor(.iHateMoney)
        XCTAssertEqual(params["payer"] as? String, "1")
    }

    func testIHateMoney_amount_isString() {
        let params = makeBill(amount: 12.99).paramsFor(.iHateMoney)
        XCTAssertEqual(params["amount"] as? String, "12.99")
    }

    // MARK: - Shared fields (same for both backends)

    func testBothBackends_alwaysHaveDate() {
        let bill = makeBill()
        XCTAssertNotNil(bill.paramsFor(.cospend)["date"])
        XCTAssertNotNil(bill.paramsFor(.iHateMoney)["date"])
    }

    func testBothBackends_alwaysHavePayer() {
        let bill = makeBill()
        XCTAssertNotNil(bill.paramsFor(.cospend)["payer"])
        XCTAssertNotNil(bill.paramsFor(.iHateMoney)["payer"])
    }

    func testBothBackends_alwaysHaveAmount() {
        let bill = makeBill()
        XCTAssertNotNil(bill.paramsFor(.cospend)["amount"])
        XCTAssertNotNil(bill.paramsFor(.iHateMoney)["amount"])
    }

    // MARK: - Bill.newBill() defaults

    func testNewBill_idIsMinusOne() {
        // id == -1 is the sentinel that signals "this bill has not been saved yet".
        // Code in ProjectManager checks for this to decide between POST and PUT.
        XCTAssertEqual(Bill.newBill().id, -1)
    }

    func testNewBill_amountIsZero() {
        XCTAssertEqual(Bill.newBill().amount, 0.0)
    }

    func testNewBill_repeatIsN() {
        XCTAssertEqual(Bill.newBill().repeat, "n")
    }

    func testNewBill_owersIsEmpty() {
        XCTAssertTrue(Bill.newBill().owers.isEmpty)
    }

    func testNewBill_payerIdIsMinusOne() {
        XCTAssertEqual(Bill.newBill().payer_id, -1)
    }
}
