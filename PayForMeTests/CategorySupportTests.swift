//
//  CategorySupportTests.swift
//  PayForMeTests
//
//  Category support for iHateMoney category forks (and the title → category suggestion).
//  Stock iHateMoney has no categories and must keep working unchanged.
//

import XCTest
@testable import PayForMe

private let forkFeatures: Set<String> = ["categoryid", "categories", "paymentmodes", "settle", "repeat"]

class CategoryTextMatchTests: XCTestCase {
    func testNormalize_foldsUmlautsAndPunctuation() {
        XCTAssertEqual(TextMatchUtils.normalize("  Käse-Brötchen, ÄPFEL! "), "kaese broetchen aepfel")
        XCTAssertEqual(TextMatchUtils.normalize("Straße"), "strasse")
    }

    func testTokenize_emptyAndSymbolOnlyGiveNoTokens() {
        XCTAssertEqual(TextMatchUtils.tokenize(""), [])
        XCTAssertEqual(TextMatchUtils.tokenize("--- !!!"), [])
    }

    func testContainsTokenSequence_respectsWordBoundaries() {
        // "gas" must not match inside "gaststaette".
        XCTAssertFalse(TextMatchUtils.containsTokenSequence(["gaststaette"], ["gas"]))
        XCTAssertTrue(TextMatchUtils.containsTokenSequence(["uber", "eats", "x"], ["uber", "eats"]))
        XCTAssertFalse(TextMatchUtils.containsTokenSequence(["a"], ["a", "b"]))
    }
}

class CategoryClassifierTests: XCTestCase {
    func testClassify_knownShopsAndKeywords() {
        XCTAssertEqual(CategoryClassifier.classify(title: "REWE Einkauf")?.cospendId, -1)
        XCTAssertEqual(CategoryClassifier.classify(title: "Pizza am Hafen")?.cospendId, -12)
        XCTAssertEqual(CategoryClassifier.classify(title: "Tanken")?.cospendId, -14)
        XCTAssertEqual(CategoryClassifier.classify(title: "Miete Oktober")?.cospendId, -3)
        XCTAssertEqual(CategoryClassifier.classify(title: "Apotheke")?.cospendId, -6)
    }

    func testClassify_longestPhraseWins() {
        // "uber eats" (2 tokens, restaurant) beats "uber" (1 token, transport).
        XCTAssertEqual(CategoryClassifier.classify(title: "Uber Eats")?.cospendId, -12)
        XCTAssertEqual(CategoryClassifier.classify(title: "Uber nach Hause")?.cospendId, -14)
    }

    func testClassify_noMatchAndEmpty() {
        XCTAssertNil(CategoryClassifier.classify(title: "Geschenk für Oma"))
        XCTAssertNil(CategoryClassifier.classify(title: ""))
    }

    func testClassify_substringDoesNotMatch() {
        XCTAssertNil(CategoryClassifier.classify(title: "Gaststätte"))
    }

    func testSuggest_prefersExactGlobalIdInTheList() {
        let id = CategoryClassifier.suggestCategoryId(title: "Rewe", in: CospendTag.globalCategories)
        XCTAssertEqual(id, -1)
    }

    func testSuggest_matchesOwnCategoryByName() {
        let own = [CospendTag(id: 5, name: "Lebensmittel", color: nil, icon: "🥦", order: 0)]
        XCTAssertEqual(CategoryClassifier.suggestCategoryId(title: "Rewe", in: own), 5)
    }

    func testSuggest_nilWhenProjectHasNoFittingCategory() {
        let own = [CospendTag(id: 5, name: "Haustiere", color: nil, icon: "", order: 0)]
        XCTAssertNil(CategoryClassifier.suggestCategoryId(title: "Rewe", in: own))
        XCTAssertNil(CategoryClassifier.suggestCategoryId(title: "Rewe", in: []))
    }
}

class CategoryProjectModelTests: XCTestCase {
    func testStockIHateMoney_categorizesLocally() {
        let project = Project.makeIHateMoney()
        XCTAssertTrue(project.supportsCategories)
        XCTAssertTrue(project.usesLocalCategories)
        XCTAssertEqual(project.pickableCategories.count, CospendTag.globalCategories.count)
    }

    func testStockIHateMoney_localCategoryFillsInWhereServerHasNone() {
        let project = Project.makeIHateMoney()
        project.localCategories = [7: -1]
        XCTAssertEqual(project.categoryId(of: .make(id: 7)), -1)
        XCTAssertEqual(project.category(for: .make(id: 7))?.name, "Grocery")
        XCTAssertNil(project.categoryId(of: .make(id: 8)))
    }

    func testFork_serverCategoryWinsAndLocalIsIgnored() {
        let project = Project.makeIHateMoney()
        project.features = forkFeatures
        project.localCategories = [7: -1]
        XCTAssertFalse(project.usesLocalCategories)
        XCTAssertNil(project.categoryId(of: .make(id: 7)))
        XCTAssertEqual(project.categoryId(of: .make(id: 7, categoryid: -12)), -12)
    }

    func testCospend_neverUsesLocalCategories() {
        XCTAssertFalse(Project.makeCospend().usesLocalCategories)
    }

    func testForkIHateMoney_offersGlobalPlusOwnCategories() {
        let project = Project.makeIHateMoney()
        project.features = forkFeatures
        project.categories = [CospendTag(id: 3, name: "Pets", color: nil, icon: "🐕", order: 0)]

        XCTAssertTrue(project.supportsCategories)
        XCTAssertEqual(project.pickableCategories.count, CospendTag.globalCategories.count + 1)
        XCTAssertEqual(project.category(for: .make(categoryid: -1))?.name, "Grocery")
        XCTAssertEqual(project.category(for: .make(categoryid: 3))?.name, "Pets")
        XCTAssertEqual(project.listedCategoryId(-12), -12)
        XCTAssertEqual(project.listedCategoryId(999), 0)
    }

    func testCospend_pickableCategoriesStayTheProjectsOwn() {
        // Upstream behaviour: Cospend lists only the project's categories.
        let project = Project.makeCospend(categories: [testCategoryGrocery])
        XCTAssertEqual(project.pickableCategories.map(\.id), [122])
    }

    func testBillDecoding_nullCategoryFromFork() throws {
        let json = """
        [{"id": 1, "payer_id": 1, "owers": [], "amount": 5.0, "date": "2026-05-14", "what": "x",
          "categoryid": null, "paymentmodeid": null, "repeat": "n"}]
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.cospend)
        let bills = try decoder.decode([Bill].self, from: json)
        XCTAssertNil(bills.first?.categoryid)
    }
}

class IHateMoneyBillParamsTests: XCTestCase {
    func testStockServer_sendsNoCategoryFields() {
        let params = Bill.make(categoryid: -1, paymentmodeid: 4).paramsFor(.iHateMoney)
        XCTAssertNil(params["categoryid"])
        XCTAssertNil(params["paymentmodeid"])
    }

    func testFork_sendsCategoryAndPaymentModeAsStrings() {
        let params = Bill.make(categoryid: -1, paymentmodeid: 4).paramsFor(.iHateMoney, features: forkFeatures)
        XCTAssertEqual(params["categoryid"] as? String, "-1")
        XCTAssertEqual(params["paymentmodeid"] as? String, "4")
    }

    func testFork_noneIsEmptyStringNotZero() {
        // The fork's form rejects "0" but accepts "" as "none".
        for bill in [Bill.make(), Bill.make(categoryid: 0, paymentmodeid: 0)] {
            let params = bill.paramsFor(.iHateMoney, features: forkFeatures)
            XCTAssertEqual(params["categoryid"] as? String, "")
            XCTAssertEqual(params["paymentmodeid"] as? String, "")
        }
    }

    func testFork_payedForStaysAnArray() {
        let params = Bill.make().paramsFor(.iHateMoney, features: forkFeatures)
        XCTAssertNotNil(params["payed_for"] as? [String])
    }
}

class AutoCategoryViewModelTests: XCTestCase {
    private var savedProject: Project!

    override func setUp() {
        super.setUp()
        savedProject = ProjectManager.shared.currentProject
    }

    override func tearDown() {
        ProjectManager.shared.currentProject = savedProject
        super.tearDown()
    }

    private func makeViewModel(enabled: Bool, bill: Bill = .newBill()) -> BillDetailViewModel {
        let project = Project.makeIHateMoney()
        project.features = forkFeatures
        project.members = [testAlice.id: testAlice]
        ProjectManager.shared.currentProject = project
        let vm = BillDetailViewModel(currentBill: bill)
        vm.autoCategoryEnabled = { enabled }
        return vm
    }

    func testTitleSetsCategory_whenEnabled() {
        let vm = makeViewModel(enabled: true)
        vm.topic = "Rewe"
        XCTAssertEqual(vm.selectedCategoryId, -1)
    }

    func testTitleDoesNothing_whenDisabled() {
        let vm = makeViewModel(enabled: false)
        vm.topic = "Rewe"
        XCTAssertEqual(vm.selectedCategoryId, 0)
    }

    func testManualChoiceIsNeverOverwritten() {
        let vm = makeViewModel(enabled: true)
        vm.categoryPickerSelection.wrappedValue = -3
        vm.topic = "Rewe"
        XCTAssertEqual(vm.selectedCategoryId, -3)
    }

    func testSuggestionIsRevertedWhenTitleNoLongerMatches() {
        let vm = makeViewModel(enabled: true)
        vm.topic = "Rewe"
        vm.topic = "Rew"
        XCTAssertEqual(vm.selectedCategoryId, 0)
    }

    func testExistingBillKeepsItsCategory() {
        let vm = makeViewModel(enabled: true, bill: .make(id: 7, what: "x", categoryid: -6))
        vm.topic = "Rewe"
        XCTAssertEqual(vm.selectedCategoryId, -6)
    }
}

class CategoryIconTests: XCTestCase {
    func testTextDefaultEmojiGetsVariationSelector() {
        // 🌩 and 🛍 would render as monochrome text glyphs without it.
        XCTAssertEqual(CospendTag.emojiPresentation("🌩"), "🌩\u{FE0F}")
        XCTAssertEqual(CospendTag.emojiPresentation("🛍"), "🛍\u{FE0F}")
    }

    func testColorEmojiAndSelectorAreLeftAlone() {
        XCTAssertEqual(CospendTag.emojiPresentation("🛒"), "🛒")
        XCTAssertEqual(CospendTag.emojiPresentation("🛍\u{FE0F}"), "🛍\u{FE0F}")
        XCTAssertEqual(CospendTag.emojiPresentation("🐕"), "🐕")
    }

    func testPlainTextIconsAreUntouched() {
        XCTAssertEqual(CospendTag.emojiPresentation("#"), "#")
        XCTAssertEqual(CospendTag.emojiPresentation("1"), "1")
        XCTAssertEqual(CospendTag.emojiPresentation("A"), "A")
    }

    func testEveryBuiltInCategoryLabelIsClean() {
        for tag in CospendTag.globalCategories {
            XCTAssertFalse(tag.label.hasPrefix(" "), tag.label)
            XCTAssertTrue(tag.label.hasSuffix(tag.displayName), tag.label)
        }
    }
}

class CategoryColorTests: XCTestCase {
    func testParsesHexWithAndWithoutHash() throws {
        let a = try XCTUnwrap(CospendTag(id: 1, name: "a", color: "#ff0000", icon: nil, order: nil).rgb)
        XCTAssertEqual(a.red, 1)
        XCTAssertEqual(a.green, 0)
        let b = try XCTUnwrap(CospendTag(id: 1, name: "a", color: "00FF00", icon: nil, order: nil).rgb)
        XCTAssertEqual(b.green, 1)
    }

    func testEmptyOrMalformedColorIsNil() {
        for value in [nil, "", "#12", "zzzzzz", "#1234567"] {
            XCTAssertNil(CospendTag(id: 1, name: "a", color: value, icon: nil, order: nil).rgb, value ?? "nil")
        }
    }
}
