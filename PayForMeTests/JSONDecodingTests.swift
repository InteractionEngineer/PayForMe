//
//  JSONDecodingTests.swift
//  PayForMeTests
//
//  Tests that the JSON responses returned by Cospend and iHateMoney are decoded
//  correctly into our model types.
//
//  WHY THIS MATTERS:
//  Both backends return JSON, but the field names and date formats must match
//  our Swift structs exactly. A typo in a CodingKey or a wrong DateFormatter
//  would cause the decoder to throw and the app to show an empty list instead
//  of an error message — a silent data loss that's hard to debug in production.
//
//  We test decoding in isolation (no network) so failures point to model/decoder
//  issues, not connectivity issues.
//

import XCTest
@testable import PayForMe

class JSONDecodingTests: XCTestCase {

    // This decoder mirrors the one NetworkService creates internally.
    // If NetworkService ever changes its decoder config, update this too.
    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .formatted(DateFormatter.cospend)
        return d
    }

    // MARK: - Bill decoding

    func testDecodeSingleBill() throws {
        let json = """
        [{
            "id": 7,
            "amount": 42.50,
            "what": "Groceries",
            "date": "2026-05-14",
            "payer_id": 2,
            "owers": [
                {"id": 1, "weight": 1, "name": "Alice", "activated": true},
                {"id": 2, "weight": 1, "name": "Bob",   "activated": true}
            ],
            "repeat": "n",
            "lastchanged": 1705744800
        }]
        """.data(using: .utf8)!

        let bills = try decoder.decode([Bill].self, from: json)
        XCTAssertEqual(bills.count, 1)
        let bill = bills[0]
        XCTAssertEqual(bill.id, 7)
        XCTAssertEqual(bill.amount, 42.50, accuracy: 0.001)
        XCTAssertEqual(bill.what, "Groceries")
        XCTAssertEqual(bill.payer_id, 2)
        XCTAssertEqual(bill.owers.count, 2)
        XCTAssertEqual(bill.repeat, "n")
        XCTAssertEqual(bill.lastchanged, 1705744800)
    }

    func testDecodeBill_dateUsesYYYYMMDD() throws {
        // This is the key contract with Cospend: date strings are yyyy-MM-dd.
        // If a backend ever returns a timestamp integer instead, decoding would fail.
        let json = """
        [{"id": 1, "amount": 10.0, "what": "Coffee", "date": "2026-05-14",
          "payer_id": 1, "owers": [], "repeat": "n", "lastchanged": null}]
        """.data(using: .utf8)!

        let bills = try decoder.decode([Bill].self, from: json)
        let expected = DateFormatter.cospend.date(from: "2026-05-14")!
        XCTAssertEqual(bills[0].date, expected)
    }

    func testDecodeBill_optionalFieldsAbsent() throws {
        // Both `repeat` and `lastchanged` are optional in the model.
        // Old Cospend versions may omit them; the decoder must not throw.
        let json = """
        [{"id": 3, "amount": 5.0, "what": "Water", "date": "2026-05-14",
          "payer_id": 1, "owers": []}]
        """.data(using: .utf8)!

        let bills = try decoder.decode([Bill].self, from: json)
        XCTAssertNil(bills[0].lastchanged)
        XCTAssertNil(bills[0].repeat)
    }

    func testDecodeBill_lastchangedNull() throws {
        // Some Cospend versions send `"lastchanged": null` explicitly.
        let json = """
        [{"id": 4, "amount": 5.0, "what": "Tea", "date": "2026-05-14",
          "payer_id": 1, "owers": [], "lastchanged": null}]
        """.data(using: .utf8)!

        let bills = try decoder.decode([Bill].self, from: json)
        XCTAssertNil(bills[0].lastchanged)
    }

    func testDecodeBill_owersIncludeFullPersonData() throws {
        let json = """
        [{"id": 5, "amount": 20.0, "what": "Snacks", "date": "2026-05-14",
          "payer_id": 1, "owers": [
            {"id": 1, "weight": 2, "name": "Alice", "activated": true,
             "color": {"r": 255, "g": 0, "b": 0}}
          ], "repeat": "n"}]
        """.data(using: .utf8)!

        let bills = try decoder.decode([Bill].self, from: json)
        let ower = bills[0].owers[0]
        XCTAssertEqual(ower.id, 1)
        XCTAssertEqual(ower.weight, 2)
        XCTAssertEqual(ower.name, "Alice")
        XCTAssertEqual(ower.color?.r, 255)
    }

    func testDecodeMultipleBills() throws {
        let json = """
        [
          {"id": 1, "amount": 10.0, "what": "A", "date": "2024-01-01", "payer_id": 1, "owers": []},
          {"id": 2, "amount": 20.0, "what": "B", "date": "2024-01-02", "payer_id": 2, "owers": []}
        ]
        """.data(using: .utf8)!

        let bills = try decoder.decode([Bill].self, from: json)
        XCTAssertEqual(bills.count, 2)
    }

    func testDecodeEmptyBillsArray() throws {
        let json = "[]".data(using: .utf8)!
        let bills = try decoder.decode([Bill].self, from: json)
        XCTAssertTrue(bills.isEmpty)
    }

    // MARK: - Person / Member decoding

    func testDecodePerson_withColor() throws {
        // Cospend stores per-member colours (RGB). PersonColor must decode correctly.
        let json = """
        [{"id": 1, "weight": 1, "name": "Alice", "activated": true,
          "color": {"r": 60, "g": 110, "b": 186}}]
        """.data(using: .utf8)!

        let members = try decoder.decode([Person].self, from: json)
        XCTAssertEqual(members[0].color?.r, 60)
        XCTAssertEqual(members[0].color?.g, 110)
        XCTAssertEqual(members[0].color?.b, 186)
    }

    func testDecodePerson_withoutColor() throws {
        // color is optional — members added without choosing a colour have no colour.
        let json = """
        [{"id": 2, "weight": 1, "name": "Bob", "activated": true}]
        """.data(using: .utf8)!

        let members = try decoder.decode([Person].self, from: json)
        XCTAssertNil(members[0].color)
    }

    func testDecodePerson_inactiveMemberDecodesSuccessfully() throws {
        // Decoding must never fail for inactive members. NetworkService filters
        // them out after decoding — but the decode step itself must not throw.
        let json = """
        [{"id": 5, "weight": 1, "name": "Ghost", "activated": false}]
        """.data(using: .utf8)!

        let members = try decoder.decode([Person].self, from: json)
        XCTAssertFalse(members[0].activated)
    }

    func testDecodeMembers_activationFilter() {
        // This replicates the filter NetworkService applies after decoding:
        //   members.filter { $0.activated }
        // Inactive members (e.g. deleted users) must not appear in the member list.
        let all = [
            Person(id: 1, weight: 1, name: "Alice",   activated: true),
            Person(id: 2, weight: 1, name: "Deleted", activated: false),
            Person(id: 3, weight: 1, name: "Bob",     activated: true),
        ]
        let active = all.filter { $0.activated }

        XCTAssertEqual(active.count, 2)
        XCTAssertFalse(active.contains { $0.name == "Deleted" },
                       "Inactive member must be filtered out")
    }

    func testDecodeMembers_mixedActivation() throws {
        let json = """
        [
          {"id": 1, "weight": 1, "name": "Alice", "activated": true},
          {"id": 2, "weight": 1, "name": "Bob",   "activated": false},
          {"id": 3, "weight": 1, "name": "Carla", "activated": true}
        ]
        """.data(using: .utf8)!

        let all = try decoder.decode([Person].self, from: json)
        XCTAssertEqual(all.count, 3, "Decoder returns all members before filtering")

        let active = all.filter { $0.activated }
        XCTAssertEqual(active.count, 2)
    }

    // MARK: - APIProject decoding (used by getProjectName)

    func testDecodeAPIProject() throws {
        // getProjectName fetches the project's display name from the server.
        // The response contains `name` (String) and `id` (String, not Int).
        let json = """
        {"name": "My Shared Trip", "id": "trip-2026"}
        """.data(using: .utf8)!

        let apiProject = try JSONDecoder().decode(APIProject.self, from: json)
        XCTAssertEqual(apiProject.name, "My Shared Trip")
        XCTAssertEqual(apiProject.id, "trip-2026")
    }

    func testDecodeAPIProject_idIsString() throws {
        // The Cospend API returns the project id as a string, not an integer.
        // If this field were typed as Int in the model, decoding would fail silently.
        let json = """
        {"name": "Test", "id": "abc123"}
        """.data(using: .utf8)!

        XCTAssertNoThrow(try JSONDecoder().decode(APIProject.self, from: json))
    }

    // MARK: - Bill sorting logic (mirrors NetworkService sort after decode)

    func testBillsSortByLastchangedDescending() throws {
        // NetworkService sorts decoded bills so the most recently *modified* bill
        // appears first. This ensures edits on another device appear at the top.
        let json = """
        [
          {"id": 1, "amount": 5.0, "what": "A", "date": "2026-01-01",
           "payer_id": 1, "owers": [], "lastchanged": 100},
          {"id": 2, "amount": 5.0, "what": "B", "date": "2026-01-02",
           "payer_id": 1, "owers": [], "lastchanged": 200},
          {"id": 3, "amount": 5.0, "what": "C", "date": "2026-01-03",
           "payer_id": 1, "owers": [], "lastchanged": 50}
        ]
        """.data(using: .utf8)!

        let bills = try decoder.decode([Bill].self, from: json)
        let sorted = bills.sorted {
            if let l1 = $0.lastchanged, let l2 = $1.lastchanged { return l1 > l2 }
            return $0.date > $1.date
        }
        XCTAssertEqual(sorted.map { $0.id }, [2, 1, 3])
    }

    func testBillsSortFallsBackToDateWhenNoLastchanged() throws {
        let json = """
        [
          {"id": 1, "amount": 5.0, "what": "A", "date": "2026-01-01",
           "payer_id": 1, "owers": []},
          {"id": 2, "amount": 5.0, "what": "B", "date": "2026-01-03",
           "payer_id": 1, "owers": []},
          {"id": 3, "amount": 5.0, "what": "C", "date": "2026-01-02",
           "payer_id": 1, "owers": []}
        ]
        """.data(using: .utf8)!

        let bills = try decoder.decode([Bill].self, from: json)
        let sorted = bills.sorted {
            if let l1 = $0.lastchanged, let l2 = $1.lastchanged { return l1 > l2 }
            return $0.date > $1.date
        }
        XCTAssertEqual(sorted.map { $0.id }, [2, 3, 1])
    }
}
