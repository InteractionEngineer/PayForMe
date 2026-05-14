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

    @MainActor
    func testScreenshots() {
        let app = XCUIApplication()
        Snapshot.setLanguage(app)
        setupSnapshot(app)
        app.launchArguments += ["UI-Testing"]
        app.launch()
        let tabBarButtons = app.tabBars.firstMatch.buttons
        snapshot("Bill List")
        tabBarButtons.element(boundBy: 1).tap()
        snapshot("Balance List")
        tabBarButtons.element(boundBy: 2).tap()
        snapshot("Known Projects")
        tabBarButtons.element(boundBy: 0).tap()
        app.buttons["Add Bill"].tap()
        snapshot("Add Bill")
    }

    @MainActor
    func testScreenshotsEmpty() {
        let app = XCUIApplication()
        Snapshot.setLanguage(app)
        setupSnapshot(app)
        app.launchArguments += ["UI-Testing", "Onboarding"]
        app.launch()
        snapshot("Onboarding")
    }
}
