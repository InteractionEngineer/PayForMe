//
//  AddProjectManuallyTests.swift
//  PayForMeTests
//
//  Tests for AddProjectManualViewModel — the view model that drives the manual
//  project-add flow (the "Enter server URL" screen).
//
//  WHY THIS MATTERS:
//  Adding a new project is the very first thing a new user does. If URL parsing
//  is broken, the app is completely unusable. Cospend URLs are especially tricky:
//  they embed the project name and password inside the URL path, so users often
//  paste a full URL like:
//
//    https://cloud.example.com/index.php/apps/cospend/myproject/mypassword
//
//  The ViewModel must strip the Nextcloud-specific path, keep only the server
//  root, and auto-fill the project name and password fields. Without this, the
//  user would have to know and type all three values separately.
//
//  NOTE ON TIMING:
//  serverAddressFormatted fires synchronously (no debounce) — 1-second timeout is fine.
//  validatedInput has a 1-second debounce — tests that subscribe to it need 2 seconds.
//

import Combine
import XCTest
@testable import PayForMe

class AddProjectManuallyTests: XCTestCase {

    // XCTest creates a new instance per test method, so viewmodel is always fresh.
    var viewmodel = AddProjectManualViewModel()
    var subscriptions = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        // The view model validates the server over the network once a full
        // triple is entered. Intercept it so tests stay offline and deterministic.
        URLProtocol.registerClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            let body = #"{"name": "nameXY", "id": "nameXY"}"#.data(using: .utf8)!
            return (response, body)
        }
    }

    override func tearDownWithError() throws {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.reset()
        subscriptions.removeAll()
    }

    // MARK: - URL normalization (serverAddressFormatted)

    func testHTTPSPrefix_addsMissingScheme() throws {
        // Users who copy-paste a server address from a browser's address bar often
        // omit the scheme. The ViewModel must prepend "https://" automatically.
        viewmodel.serverAddress = "myserver.de"
        let exp = expectation(description: "https:// prefix added")
        viewmodel.serverAddressFormatted.sink { formatted in
            XCTAssertEqual(formatted, "https://myserver.de")
            exp.fulfill()
        }.store(in: &subscriptions)
        waitForExpectations(timeout: 1)
    }

    func testHTTPSPrefix_doesNotDoubleAdd() throws {
        // If the user already typed the scheme, it must not be duplicated.
        viewmodel.serverAddress = "https://myserver.de"
        let exp = expectation(description: "no double https://")
        viewmodel.serverAddressFormatted.sink { formatted in
            XCTAssertEqual(formatted, "https://myserver.de")
            exp.fulfill()
        }.store(in: &subscriptions)
        waitForExpectations(timeout: 1)
    }

    func testCospendSuffix_isStripped() throws {
        // Cospend's share link includes the full Nextcloud path. We only want the
        // server root so we can build API URLs ourselves.
        viewmodel.serverAddress = "https://myserver.de/index.php/apps/cospend/"
        let exp = expectation(description: "Cospend trunk removed")
        viewmodel.serverAddressFormatted.sink { formatted in
            XCTAssertEqual(formatted, "https://myserver.de")
            exp.fulfill()
        }.store(in: &subscriptions)
        waitForExpectations(timeout: 1)
    }

    func testPrefixAndSuffix_bothApplied() throws {
        // The two normalizations must compose: add https://, then strip the path.
        viewmodel.serverAddress = "myserver.de/index.php/apps/cospend/"
        let exp = expectation(description: "prefix added and trunk removed")
        viewmodel.serverAddressFormatted.sink { formatted in
            XCTAssertEqual(formatted, "https://myserver.de")
            exp.fulfill()
        }.store(in: &subscriptions)
        waitForExpectations(timeout: 1)
    }

    // MARK: - Autofill from URL path

    func testAutofill_projectNameExtracted() throws {
        // When the URL contains the Cospend path with a project name but no
        // password, the ViewModel must extract the project name and use "no-pass"
        // as the default password (Cospend's convention for passwordless projects).
        viewmodel.serverAddress = "https://myserver.de/index.php/apps/cospend/nameXY"
        let exp1 = expectation(description: "server stripped")
        let exp2 = expectation(description: "project name filled")
        let exp3 = expectation(description: "default password set")
        viewmodel.serverAddressFormatted.sink { formatted in
            XCTAssertEqual(formatted, "https://myserver.de")
            exp1.fulfill()
        }.store(in: &subscriptions)
        viewmodel.$projectName.sink { name in
            XCTAssertEqual(name, "nameXY")
            exp2.fulfill()
        }.store(in: &subscriptions)
        viewmodel.$projectPassword.sink { password in
            XCTAssertEqual(password, "no-pass")
            exp3.fulfill()
        }.store(in: &subscriptions)
        waitForExpectations(timeout: 1)
    }

    func testAutofill_projectNameAndPasswordExtracted() throws {
        // When the URL contains both project name and password in the path,
        // both fields must be auto-filled.
        viewmodel.serverAddress = "https://myserver.de/index.php/apps/cospend/nameXY/passwordXY"
        let exp1 = expectation(description: "server stripped")
        let exp2 = expectation(description: "project name filled")
        let exp3 = expectation(description: "password filled")
        viewmodel.serverAddressFormatted.sink { formatted in
            XCTAssertEqual(formatted, "https://myserver.de")
            exp1.fulfill()
        }.store(in: &subscriptions)
        viewmodel.$projectName.sink { name in
            XCTAssertEqual(name, "nameXY")
            exp2.fulfill()
        }.store(in: &subscriptions)
        viewmodel.$projectPassword.sink { password in
            XCTAssertEqual(password, "passwordXY")
            exp3.fulfill()
        }.store(in: &subscriptions)
        waitForExpectations(timeout: 1)
    }

    // MARK: - Project object creation (validatedInput)

    func testProjectCreation_cospendBackend() throws {
        // validatedInput emits a complete Project object once the debounce settles.
        // This is the object that gets passed to NetworkService for server validation.
        viewmodel.serverAddress = "https://myserver.de/index.php/apps/cospend/nameXY/passwordXY"
        viewmodel.projectType = .cospend
        let exp = expectation(description: "Project emitted")
        viewmodel.validatedInput.sink { project in
            XCTAssertEqual(project.backend, .cospend)
            XCTAssertEqual(project.name, "nameXY")
            XCTAssertEqual(project.password, "passwordXY")
            XCTAssertEqual(project.url.absoluteString, "https://myserver.de")
            exp.fulfill()
        }.store(in: &subscriptions)
        waitForExpectations(timeout: 2)
    }

    func testProjectCreation_tokenBasedCospend() throws {
        // Newer Cospend share links use a random token instead of a human-readable
        // project name. The token becomes both `name` and `token` on the Project.
        viewmodel.serverAddress = "https://myserver.de/index.php/apps/cospend/02939asdasd12asdj23/no-pass"
        viewmodel.projectType = .cospend
        let exp = expectation(description: "Token-based project emitted")
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
