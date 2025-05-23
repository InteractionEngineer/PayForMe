//
//  PayForMeUITests.swift
//  PayForMeUITests
//
//  Created by Max Tharr on 13.03.20.
//

import XCTest

class PayForMeUITests: XCTestCase {
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testScreenshots() async throws {
        let app = XCUIApplication()
        await Snapshot.setLanguage(app)
        await setupSnapshot(app)
        app.launchArguments += ["UI-Testing"]
        app.launch()
        let tabBarsQuery = app.tabBars
        await snapshot("Bill List")
        tabBarsQuery.children(matching: .button).element(boundBy: 1).tap()
        await snapshot("Balance List")
        tabBarsQuery.children(matching: .button).element(boundBy: 2).tap()
        await snapshot("Known Projects")
        tabBarsQuery.children(matching: .button).element(boundBy: 1).tap()
        app.buttons["Add Bill"].tap()
        await snapshot("Add Bill")
    }

    func testScreenshotsEmpty() async throws {
        let app = XCUIApplication()
        await Snapshot.setLanguage(app)
        await setupSnapshot(app)
        app.launchArguments += ["UI-Testing", "Onboarding"]
        app.launch()
        await snapshot("Onboarding")
    }
}
