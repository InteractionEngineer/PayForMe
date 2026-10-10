//
//  BillDetailViewModelTests.swift
//  PayForMeTests
//

import XCTest
@testable import PayForMe

class BillDetailViewModelTests: XCTestCase {

    private var savedProject: Project!

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
        MockURLProtocol.reset()
        savedProject = ProjectManager.shared.currentProject
    }

    override func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        ProjectManager.shared.currentProject = savedProject
        super.tearDown()
    }

    private func makeViewModel(
        bill: Bill,
        categories: [CospendTag] = [],
        paymentModes: [CospendTag] = []
    ) -> BillDetailViewModel {
        let project = Project.makeCospend(categories: categories,
                                          paymentModes: paymentModes)
        project.members = [testAlice.id: testAlice, testBob.id: testBob]
        ProjectManager.shared.currentProject = project
        return BillDetailViewModel(currentBill: bill)
    }

    // MARK: - createBill() keeps the category id

    func testCreateBill_keepsNegativeCategoryId_whenCategoriesLoaded() {
        // The regression: a settlement bill's built-in category is not in the project list, and
        // the list IS loaded, so the old clearing logic applied and wrote 0.
        let vm = makeViewModel(
            bill: .make(categoryid: testUnlistedNegativeTagId),
            categories: [testCategoryGrocery]
        )

        XCTAssertEqual(vm.createBill()?.categoryid, testUnlistedNegativeTagId)
    }

    func testCreateBill_keepsUnknownPositiveCategoryId() {
        // A category deleted on the server, its id still on the bill. Verified against a live
        // instance: the server neither validates nor resets such an id, so there is nothing to
        // tidy up — clearing it would be the app changing a field the user never touched.
        let vm = makeViewModel(
            bill: .make(categoryid: testUnlistedPositiveTagId),
            categories: [testCategoryGrocery]
        )

        XCTAssertEqual(vm.createBill()?.categoryid, testUnlistedPositiveTagId)
    }

    func testCreateBill_keepsUnknownPositiveCategoryId_whileThePickerShowsNone() {
        // Display and saved value disagree here, and that is the design: the picker has no row for
        // an id the project does not list, while the id itself is nobody's business but the
        // server's.
        let vm = makeViewModel(
            bill: .make(categoryid: testUnlistedPositiveTagId),
            categories: [testCategoryGrocery]
        )

        XCTAssertEqual(vm.categoryPickerSelection.wrappedValue, 0, "picker reads none")
        XCTAssertEqual(vm.createBill()?.categoryid, testUnlistedPositiveTagId,
                       "but the id goes out unchanged")
    }

    func testCreateBill_keepsCategoryId_whenCategoryListIsEmpty() {
        // Tags never loaded (first launch, or the tag request failed). The picker is hidden in
        // this state, so nobody could have chosen anything — the id must pass through.
        let vm = makeViewModel(bill: .make(categoryid: testCategoryGrocery.id))

        XCTAssertEqual(vm.createBill()?.categoryid, testCategoryGrocery.id)
    }

    func testCreateBill_keepsSelectedCategoryFromList() {
        let vm = makeViewModel(
            bill: .make(categoryid: testCategoryGrocery.id),
            categories: [testCategoryGrocery]
        )

        XCTAssertEqual(vm.createBill()?.categoryid, testCategoryGrocery.id)
    }

    func testCreateBill_zeroCategoryIdStaysZero() {
        // "none" has to remain settable — 0 is the encoding the API uses for it.
        let vm = makeViewModel(bill: .make(categoryid: 0), categories: [testCategoryGrocery])

        XCTAssertEqual(vm.createBill()?.categoryid, 0)
    }

    func testCreateBill_nilCategoryIdBecomesZero() {
        // A bill from a project without categories carries nil; prefillData maps that to 0.
        let vm = makeViewModel(bill: .make(), categories: [testCategoryGrocery])

        XCTAssertEqual(vm.createBill()?.categoryid, 0)
    }

    // MARK: - createBill() keeps the payment mode id

    func testCreateBill_keepsNegativePaymentModeId() {
        let vm = makeViewModel(
            bill: .make(paymentmodeid: testUnlistedNegativeTagId),
            paymentModes: [testPaymentModeCash]
        )

        XCTAssertEqual(vm.createBill()?.paymentmodeid, testUnlistedNegativeTagId)
    }

    func testCreateBill_keepsUnknownPositivePaymentModeId() {
        // A payment mode deleted in Cospend, the bill edited afterwards. The server keeps such an
        // id too — bill 509 of the test project carries `paymentmodeid = 9` with only four payment
        // modes in existence, and the server reports `paymentmode: "n"` without touching the id.
        let vm = makeViewModel(
            bill: .make(paymentmodeid: testUnlistedPositiveTagId),
            paymentModes: [testPaymentModeCash]
        )

        XCTAssertEqual(vm.createBill()?.paymentmodeid, testUnlistedPositiveTagId)
    }

    func testCreateBill_keepsUnknownPositiveId_whenListNotLoaded() {
        // An empty list cannot be told apart from a tag request that failed, and treating it as
        // "nothing is listed" would clear every id on the next save. So this passes through, even
        // though it means a deleted last tag keeps its dangling id.
        let vm = makeViewModel(bill: .make(categoryid: testUnlistedPositiveTagId,
                                           paymentmodeid: testUnlistedPositiveTagId))

        XCTAssertEqual(vm.createBill()?.categoryid, testUnlistedPositiveTagId)
        XCTAssertEqual(vm.createBill()?.paymentmodeid, testUnlistedPositiveTagId)
    }

    func testCreateBill_keepsSelectedPaymentModeFromList() {
        let vm = makeViewModel(
            bill: .make(paymentmodeid: testPaymentModeCash.id),
            paymentModes: [testPaymentModeCash]
        )

        XCTAssertEqual(vm.createBill()?.paymentmodeid, testPaymentModeCash.id)
    }

    // MARK: - What ends up on the wire

    func testCreateBill_unlistedIds_surviveParamsForCospend() {
        // The assertion that describes what the server actually receives.
        let vm = makeViewModel(
            bill: .make(
                categoryid: testUnlistedNegativeTagId,
                paymentmodeid: testUnlistedNegativeTagId
            ),
            categories: [testCategoryGrocery],
            paymentModes: [testPaymentModeCash]
        )

        guard let params = vm.createBill()?.paramsFor(.cospend) else {
            return XCTFail("createBill() returned nil")
        }
        XCTAssertEqual(params["categoryid"] as? String, "-11")
        XCTAssertEqual(params["paymentmodeid"] as? String, "-11")
        // The legacy char stays the fixed "n"; the server derives the real one from
        // `paymentmodeid` and discards what the client sent.
        XCTAssertEqual(params["paymentmode"] as? String, "n")
    }

    // MARK: - prefillData()

    func testPrefill_takesNegativeCategoryIdAsSelection() {
        // Guards against a future "let's just clean it up while filling the form".
        let vm = makeViewModel(
            bill: .make(categoryid: testUnlistedNegativeTagId),
            categories: [testCategoryGrocery]
        )

        XCTAssertEqual(vm.selectedCategoryId, testUnlistedNegativeTagId)
    }

    // MARK: - Picker selection binding
    //
    // The contract these pin down: display is 0 for an id the project does not list, while the
    // stored selection keeps the original. Both halves belong in the same assertion, because
    // "shows none but saves -11" is a statement about two values.

    func testCategoryPickerSelection_showsIdFromList() {
        let vm = makeViewModel(
            bill: .make(categoryid: testCategoryGrocery.id),
            categories: [testCategoryGrocery]
        )

        XCTAssertEqual(vm.categoryPickerSelection.wrappedValue, testCategoryGrocery.id)
    }

    func testCategoryPickerSelection_showsZeroForZero() {
        let vm = makeViewModel(bill: .make(categoryid: 0), categories: [testCategoryGrocery])

        XCTAssertEqual(vm.categoryPickerSelection.wrappedValue, 0)
    }

    func testCategoryPickerSelection_showsZeroForNegativeId() {
        // A settlement bill: Cospend's built-in reimbursement category is not in the project list.
        let vm = makeViewModel(
            bill: .make(categoryid: testUnlistedNegativeTagId),
            categories: [testCategoryGrocery]
        )

        XCTAssertEqual(vm.categoryPickerSelection.wrappedValue, 0, "picker reads as none")
        XCTAssertEqual(vm.selectedCategoryId, testUnlistedNegativeTagId, "selection keeps the id")
    }

    func testCategoryPickerSelection_showsZeroForUnknownPositiveId() {
        let vm = makeViewModel(
            bill: .make(categoryid: testUnlistedPositiveTagId),
            categories: [testCategoryGrocery]
        )

        XCTAssertEqual(vm.categoryPickerSelection.wrappedValue, 0)
        XCTAssertEqual(vm.selectedCategoryId, testUnlistedPositiveTagId)
    }

    func testPaymentModePickerSelection_showsIdFromList() {
        let vm = makeViewModel(
            bill: .make(paymentmodeid: testPaymentModeCash.id),
            paymentModes: [testPaymentModeCash]
        )

        XCTAssertEqual(vm.paymentModePickerSelection.wrappedValue, testPaymentModeCash.id)
    }

    func testPaymentModePickerSelection_showsZeroForNegativeId() {
        let vm = makeViewModel(
            bill: .make(paymentmodeid: testUnlistedNegativeTagId),
            paymentModes: [testPaymentModeCash]
        )

        XCTAssertEqual(vm.paymentModePickerSelection.wrappedValue, 0)
        XCTAssertEqual(vm.selectedPaymentModeId, testUnlistedNegativeTagId)
    }

    func testCategoryPickerSelection_showsIdOnceTagListArrivesLate() {
        // prefillData() runs once in init, while the tag lists arrive later via
        // manager.$currentProject. Until they do, even a perfectly valid id reads as none — and it
        // has to start showing itself on its own once the list lands, selection unchanged.
        let vm = makeViewModel(bill: .make(categoryid: testCategoryGrocery.id))
        XCTAssertEqual(vm.categoryPickerSelection.wrappedValue, 0, "not listed yet")

        let loaded = Project.makeCospend(categories: [testCategoryGrocery])
        loaded.members = [testAlice.id: testAlice, testBob.id: testBob]
        ProjectManager.shared.currentProject = loaded

        XCTAssertEqual(vm.selectedCategoryId, testCategoryGrocery.id)
        XCTAssertEqual(vm.categoryPickerSelection.wrappedValue, testCategoryGrocery.id)
    }

    // MARK: - Writing through the binding

    func testCategoryPickerSelection_writeThroughKeepsSelection() {
        let vm = makeViewModel(bill: .make(categoryid: 0), categories: [testCategoryGrocery])

        vm.categoryPickerSelection.wrappedValue = testCategoryGrocery.id

        XCTAssertEqual(vm.selectedCategoryId, testCategoryGrocery.id)
        XCTAssertEqual(vm.categoryPickerSelection.wrappedValue, testCategoryGrocery.id)
    }

    func testCategoryPickerSelection_writingZeroReplacesUnlistedId() {
        // Pins the half we own: IF SwiftUI calls `set` when the already-marked "none" row is
        // tapped, the orphaned id is deliberately replaced by 0 — no guard, no special case.
        // Whether SwiftUI actually does that is not claimed here.
        let vm = makeViewModel(
            bill: .make(categoryid: testUnlistedNegativeTagId),
            categories: [testCategoryGrocery]
        )

        vm.categoryPickerSelection.wrappedValue = 0

        XCTAssertEqual(vm.selectedCategoryId, 0)
    }

    func testPaymentModePickerSelection_writeThroughKeepsSelection() {
        let vm = makeViewModel(bill: .make(paymentmodeid: 0), paymentModes: [testPaymentModeCash])

        vm.paymentModePickerSelection.wrappedValue = testPaymentModeCash.id

        XCTAssertEqual(vm.selectedPaymentModeId, testPaymentModeCash.id)
    }

    // MARK: - Display mapping must not reach the saved bill

    func testCreateBill_keepsNegativeCategoryId_whileThePickerShowsNone() {
        // The user's requirement in one test. Overlaps with
        // testCreateBill_keepsNegativeCategoryId_whenCategoriesLoaded on purpose — the extra
        // assertion is the display one, which stops anyone from "fixing" the data path by making
        // the saved value follow what the picker shows.
        let vm = makeViewModel(
            bill: .make(categoryid: testUnlistedNegativeTagId),
            categories: [testCategoryGrocery]
        )

        XCTAssertEqual(vm.categoryPickerSelection.wrappedValue, 0)
        XCTAssertEqual(vm.createBill()?.categoryid, testUnlistedNegativeTagId)
    }

    func testCreateBill_keepsNegativePaymentModeId_whileThePickerShowsNone() {
        let vm = makeViewModel(
            bill: .make(paymentmodeid: testUnlistedNegativeTagId),
            paymentModes: [testPaymentModeCash]
        )

        XCTAssertEqual(vm.paymentModePickerSelection.wrappedValue, 0)
        XCTAssertEqual(vm.createBill()?.paymentmodeid, testUnlistedNegativeTagId)
    }

    // MARK: - A stale tag list must not change what gets saved

    func testCreateBill_keepsIdsTheListsCannotKnowAbout() {
        // The lists are loaded but may be older than the bill: the bills request can succeed on
        // its own and bring a tag created server-side since the last tag load. Judging an id
        // against that list is exactly what must not happen, in either direction.
        let vm = makeViewModel(bill: .make(categoryid: 200, paymentmodeid: 201),
                               categories: [testCategoryGrocery],
                               paymentModes: [testPaymentModeCash])

        XCTAssertEqual(vm.createBill()?.categoryid, 200)
        XCTAssertEqual(vm.createBill()?.paymentmodeid, 201)
    }

    // MARK: - The repetition survives an edit too

    func testCreateBill_keepsTheRepetitionOfAnExistingBill() {
        // Same class of silent loss as the category: a bill set to repeat weekly in Cospend's web
        // UI stopped repeating as soon as somebody corrected its amount here, and the app has no
        // UI to set it back.
        let vm = makeViewModel(bill: .make(repeat: "w"))

        XCTAssertEqual(vm.createBill()?.repeat, "w")
    }

    func testCreateBill_keepsNoRepetitionAsN() {
        let vm = makeViewModel(bill: .make(repeat: "n"))

        XCTAssertEqual(vm.createBill()?.repeat, "n")
    }

    func testCreateBill_iHateMoney_hasNoRepetition() {
        // iHateMoney has no such concept; `paramsFor` drops the parameter for that backend anyway.
        let project = Project.makeIHateMoney()
        project.members = [testAlice.id: testAlice, testBob.id: testBob]
        ProjectManager.shared.currentProject = project
        let vm = BillDetailViewModel(currentBill: .make(repeat: "w"))

        XCTAssertNil(vm.createBill()?.repeat)
    }
}
