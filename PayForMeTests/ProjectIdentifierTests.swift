//
//  ProjectIdentifierTests.swift
//  PayForMeTests
//
//  iHateMoney addresses a project by an id it derives from the project's name.
//  That id is not shown anywhere in its web UI, so people type the name they
//  see, the request 404s, and the project stays blank — the subject of #53.
//
//  The expectations below mirror `slugify()` in `ihatemoney/utils.py`:
//
//      value = unicodedata.normalize("NFKD", value)
//      value = str(re.sub(r"[^\w\s-]", "", value).strip().lower())
//      return re.sub(r"[-\s]+", "-", value)
//

import XCTest
@testable import PayForMe

final class ProjectIdentifierTests: XCTestCase {

    // MARK: The cases from the issue

    /// "if I choose to enter in the form id: spongebob-house […] the bills and
    /// users will load with name: Spongebob-house but not with: Spongebob house"
    func testASpaceBecomesAHyphen() {
        XCTAssertEqual("Spongebob house".iHateMoneyProjectId, "spongebob-house")
    }

    /// "special characters are omitted from project ids […]
    /// `something + somethingelse` -> `something-somethingelse`"
    func testPunctuationIsDroppedAndTheGapCollapses() {
        XCTAssertEqual("something + somethingelse".iHateMoneyProjectId,
                       "something-somethingelse")
    }

    // MARK: The rules

    func testAnIdThatIsAlreadyCorrectIsUnchanged() {
        XCTAssertEqual("spongebob-house".iHateMoneyProjectId, "spongebob-house",
                       "users who do enter the real id must not be broken")
    }

    func testAccentsAreFolded() {
        XCTAssertEqual("Café Ausflug".iHateMoneyProjectId, "cafe-ausflug")
    }

    func testRunsOfSeparatorsCollapse() {
        XCTAssertEqual("Trip   2024".iHateMoneyProjectId, "trip-2024")
        XCTAssertEqual("a --  b".iHateMoneyProjectId, "a-b")
    }

    func testSurroundingWhitespaceIsTrimmed() {
        XCTAssertEqual("  Urlaub  ".iHateMoneyProjectId, "urlaub")
    }

    /// An underscore is a word character in the pattern and survives.
    func testUnderscoresSurvive() {
        XCTAssertEqual("Wohnung_WG".iHateMoneyProjectId, "wohnung_wg")
    }

    func testAStringWithNothingUsableBecomesEmpty() {
        XCTAssertEqual("!?!".iHateMoneyProjectId, "")
        XCTAssertEqual("".iHateMoneyProjectId, "")
    }

    // MARK: Backend dispatch

    func testIHateMoneyInputIsNormalised() {
        XCTAssertEqual(ProjectBackend.iHateMoney.projectIdentifier(fromUserInput: "Spongebob house"),
                       "spongebob-house")
    }

    /// Cospend addresses projects by a share token, which is case-sensitive and
    /// must survive untouched — normalising it would break every Cospend project.
    func testCospendInputIsUntouched() {
        let token = "9dA50e410157DC1ca63e594af022f3a2"
        XCTAssertEqual(ProjectBackend.cospend.projectIdentifier(fromUserInput: token), token)
    }
}
