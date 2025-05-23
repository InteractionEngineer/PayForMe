//
//  PayForMeTests.swift
//  PayForMeTests
//
//  Created by Max Tharr on 03.10.20.
//

import Combine
@testable import PayForMe
import XCTest

class AddProjectManuallyTests: XCTestCase {
    var viewmodel = AddProjectManualViewModel()
    var subscriptions = Set<AnyCancellable>()

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        subscriptions.removeAll()
    }

    func testHTTPSPrefix() throws {
        viewmodel.serverAddress = "myserver.de"
        let exp = expectation(description: "With https")
        viewmodel.serverAddressFormatted.sink { formatted in
            XCTAssertEqual("https://myserver.de", formatted)
            exp.fulfill()
        }.store(in: &subscriptions)
        waitForExpectations(timeout: 1)
    }

    func testHTTPSPrefix2() throws {
        viewmodel.serverAddress = "https://myserver.de"
        let exp = expectation(description: "No double https")
        viewmodel.serverAddressFormatted.sink { formatted in
            XCTAssertEqual("https://myserver.de", formatted)
            exp.fulfill()
        }.store(in: &subscriptions)
        waitForExpectations(timeout: 1)
    }

    func testSuffix() throws {
        viewmodel.serverAddress = "https://myserver.de/index.php/apps/cospend/"
        let exp = expectation(description: "Remove trunk")
        viewmodel.serverAddressFormatted.sink { formatted in
            XCTAssertEqual("https://myserver.de", formatted)
            exp.fulfill()
        }.store(in: &subscriptions)
        waitForExpectations(timeout: 1)
    }

    func testPreAndSuffix() throws {
        viewmodel.serverAddress = "myserver.de/index.php/apps/cospend/"
        let exp = expectation(description: "Remove trunk, add prefix")
        viewmodel.serverAddressFormatted.sink { formatted in
            XCTAssertEqual("https://myserver.de", formatted)
            exp.fulfill()
        }.store(in: &subscriptions)
        waitForExpectations(timeout: 1)
    }

    func testAutofillName() throws {
        viewmodel.serverAddress = "https://myserver.de/index.php/apps/cospend/nameXY"
        let exp1 = expectation(description: "Remove trunk, add prefix")
        let exp2 = expectation(description: "set project")
        let exp3 = expectation(description: "password empty")
        viewmodel.serverAddressFormatted.sink { formatted in
            XCTAssertEqual("https://myserver.de", formatted)
            exp1.fulfill()
        }.store(in: &subscriptions)
        viewmodel.$projectName.sink { name in
            XCTAssertEqual("nameXY", name)
            exp2.fulfill()
        }.store(in: &subscriptions)
        viewmodel.$projectPassword.sink { password in
            XCTAssertEqual("no-pass", password)
            exp3.fulfill()
        }.store(in: &subscriptions)
        waitForExpectations(timeout: 1)
    }

    func testAutofill() throws {
        viewmodel.serverAddress = "https://myserver.de/index.php/apps/cospend/nameXY/passwordXY"
        let exp1 = expectation(description: "Remove trunk, add prefix")
        let exp2 = expectation(description: "set project")
        let exp3 = expectation(description: "set password")
        viewmodel.serverAddressFormatted.sink { formatted in
            XCTAssertEqual("https://myserver.de", formatted)
            exp1.fulfill()
        }.store(in: &subscriptions)
        viewmodel.$projectName.sink { name in
            XCTAssertEqual("nameXY", name)
            exp2.fulfill()
        }.store(in: &subscriptions)
        viewmodel.$projectPassword.sink { password in
            XCTAssertEqual("passwordXY", password)
            exp3.fulfill()
        }.store(in: &subscriptions)
        waitForExpectations(timeout: 1)
    }

    func testProjectCreation() throws {
        viewmodel.serverAddress = "https://myserver.de/index.php/apps/cospend/nameXY/passwordXY"
        viewmodel.projectType = .cospend
        let exp = expectation(description: "Project created")
        viewmodel.validatedInput.sink { project in
            XCTAssertEqual(project.backend, .cospend)
            XCTAssertEqual(project.name, "nameXY")
            XCTAssertEqual(project.password, "passwordXY")
            XCTAssertEqual(project.url.absoluteString, "https://myserver.de")
            exp.fulfill()
        }.store(in: &subscriptions)
        waitForExpectations(timeout: 2)
    }

    func testProjectNewMethodCreation() throws {
        viewmodel.serverAddress = "https://myserver.de/index.php/apps/cospend/02939asdasd12asdj23/no-pass"
        viewmodel.projectType = .cospend
        let exp = expectation(description: "Project created")
        viewmodel.validatedInput.sink { project in
            XCTAssertEqual(project.backend, .cospend)
            XCTAssertEqual(project.name, "02939asdasd12asdj23")
            XCTAssertEqual(project.token, "02939asdasd12asdj23")
            XCTAssertEqual(project.password, "no-pass")
            XCTAssertEqual(project.url.absoluteString, "https://myserver.de")
            exp.fulfill()
        }.store(in: &subscriptions)
        waitForExpectations(timeout: 2)
    }
}
