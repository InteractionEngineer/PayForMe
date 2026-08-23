//
//  NetworkRequestTests.swift
//  PayForMeTests
//
//  Tests that NetworkService builds the correct HTTP requests for each backend.
//
//  WHY THIS MATTERS:
//  Cospend and iHateMoney use fundamentally different authentication and
//  parameter-passing schemes. A wrong URL path or missing auth header causes
//  a 401/404 on the server — users would see a blank screen with no error.
//
//  COSPEND CONTRACT:
//    URL path:  {server}/index.php/apps/cospend/api/projects/{token}/{password}/{endpoint}
//    Auth:      none (credentials embedded in URL path)
//    Params:    sent as URL query string for GET; not applicable here
//
//  IHATEMONEY CONTRACT:
//    URL path:  {server}/api/projects/{token}/{endpoint}  (no password in URL)
//    Auth:      HTTP Basic — base64("{token}:{password}") in Authorization header
//    Params:    sent as JSON body with Content-Type: application/json
//
//  WRITE OPERATIONS (both backends):
//    POST   /bills           — create a new bill
//    PUT    /bills/{id}      — update an existing bill
//    DELETE /bills/{id}      — delete a bill
//    POST   /members         — create a new member
//    PUT    /members/{id}    — rename a member
//    DELETE /members/{id}    — delete a member
//
//  NetworkService write methods (postBillPublisher, updateBillPublisher, etc.)
//  read `ProjectManager.shared.currentProject` to determine the backend.
//  Tests must set that property before calling them.
//

import Combine
import XCTest
@testable import PayForMe

class NetworkRequestTests: XCTestCase {

    private var subscriptions = Set<AnyCancellable>()
    private var savedProject: Project!

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
        MockURLProtocol.reset()
        savedProject = ProjectManager.shared.currentProject
    }

    override func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        subscriptions.removeAll()
        ProjectManager.shared.currentProject = savedProject
        super.tearDown()
    }

    // Returns a handler that yields an empty JSON array with a given status code.
    private func jsonHandler(status: Int = 200, body: String = "[]") -> (URLRequest) throws -> (HTTPURLResponse, Data) {
        return { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body.data(using: .utf8)!)
        }
    }

    // MARK: - Cospend: URL structure

    func testCospend_loadBills_urlEmbedsTokenAndPassword() {
        let project = Project.makeCospend(token: "mytoken", password: "mypass",
                                          url: "https://cloud.example.com", projectId: "myproject")
        MockURLProtocol.requestHandler = jsonHandler()

        let exp = expectation(description: "request intercepted")
        NetworkService.shared.loadBillsPublisher(project)
            .sink(receiveCompletion: { _ in exp.fulfill() }, receiveValue: { _ in })
            .store(in: &subscriptions)
        waitForExpectations(timeout: 2)

        guard let url = MockURLProtocol.lastCapturedRequest?.url?.absoluteString else {
            return XCTFail("No request was intercepted — MockURLProtocol may not work with URLSession.shared on this iOS version")
        }
        // The full Cospend path must be:
        // /index.php/apps/cospend/api/projects/{token}/{password}/bills
        XCTAssertTrue(
            url.contains("/index.php/apps/cospend/api/projects/mytoken/mypass/bills"),
            "Cospend must put token and password in the URL path. Got: \(url)"
        )
    }

    func testCospend_loadMembers_urlContainsMembersEndpoint() {
        let project = Project.makeCospend(token: "tok", password: "pass", projectId: "proj")
        MockURLProtocol.requestHandler = jsonHandler()

        let exp = expectation(description: "request intercepted")
        NetworkService.shared.loadMembersPublisher(project)
            .sink(receiveCompletion: { _ in exp.fulfill() }, receiveValue: { _ in })
            .store(in: &subscriptions)
        waitForExpectations(timeout: 2)

        let url = MockURLProtocol.lastCapturedRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(url.hasSuffix("/members") || url.contains("/members"),
                      "Members endpoint must end with /members. Got: \(url)")
        XCTAssertTrue(url.contains("/tok/pass/members"),
                      "Cospend must embed token and password. Got: \(url)")
    }

    func testCospend_loadBills_trailingSlashInServerURL_doesNotProduceDoubleSlash() {
        let project = Project.makeCospend(token: "tok", password: "pass",
                                          url: "https://cloud.example.com/")
        MockURLProtocol.requestHandler = jsonHandler()

        let exp = expectation(description: "request intercepted")
        NetworkService.shared.loadBillsPublisher(project)
            .sink(receiveCompletion: { _ in exp.fulfill() }, receiveValue: { _ in })
            .store(in: &subscriptions)
        waitForExpectations(timeout: 2)

        let url = MockURLProtocol.lastCapturedRequest?.url?.absoluteString ?? ""
        XCTAssertFalse(url.contains("com//"),
                       "Server URL with trailing slash must not produce a double slash. Got: \(url)")
        XCTAssertTrue(url.contains("/index.php/apps/cospend/api/projects/tok/pass/bills"),
                      "Cospend path must remain correct with trailing-slash server URL. Got: \(url)")
    }

    // MARK: - Cospend: no auth header

    func testCospend_loadBills_noAuthorizationHeader() {
        // Cospend authenticates via URL path, NOT HTTP Basic Auth.
        let project = Project.makeCospend()
        MockURLProtocol.requestHandler = jsonHandler()

        let exp = expectation(description: "request intercepted")
        NetworkService.shared.loadBillsPublisher(project)
            .sink(receiveCompletion: { _ in exp.fulfill() }, receiveValue: { _ in })
            .store(in: &subscriptions)
        waitForExpectations(timeout: 2)

        XCTAssertNil(
            MockURLProtocol.lastCapturedRequest?.value(forHTTPHeaderField: "Authorization"),
            "Cospend requests must NOT have an Authorization header"
        )
    }

    // MARK: - iHateMoney: URL structure

    func testIHateMoney_loadBills_urlDoesNotContainPassword() {
        // iHateMoney uses HTTP Basic Auth — the password must NEVER appear in the URL.
        let project = Project.makeIHateMoney(token: "mytoken", password: "secret",
                                             url: "https://ihatemoney.org", projectId: "myproject")
        MockURLProtocol.requestHandler = jsonHandler()

        let exp = expectation(description: "request intercepted")
        NetworkService.shared.loadBillsPublisher(project)
            .sink(receiveCompletion: { _ in exp.fulfill() }, receiveValue: { _ in })
            .store(in: &subscriptions)
        waitForExpectations(timeout: 2)

        let url = MockURLProtocol.lastCapturedRequest?.url?.absoluteString ?? ""
        XCTAssertFalse(url.contains("secret"),
                       "iHateMoney password must NOT appear in the URL. Got: \(url)")
        XCTAssertTrue(url.contains("/api/projects/myproject/bills"),
                      "iHateMoney URL must use /api/projects/{token}/bills. Got: \(url)")
    }

    // MARK: - iHateMoney: Basic Auth header

    func testIHateMoney_loadBills_hasBasicAuthHeader() {
        // The Authorization header format is: "Basic " + base64("{token}:{password}")
        let project = Project.makeIHateMoney(token: "mytoken", password: "secret")
        MockURLProtocol.requestHandler = jsonHandler()

        let exp = expectation(description: "request intercepted")
        NetworkService.shared.loadBillsPublisher(project)
            .sink(receiveCompletion: { _ in exp.fulfill() }, receiveValue: { _ in })
            .store(in: &subscriptions)
        waitForExpectations(timeout: 2)

        guard let auth = MockURLProtocol.lastCapturedRequest?.value(forHTTPHeaderField: "Authorization") else {
            return XCTFail("iHateMoney requests must include an Authorization header")
        }
        XCTAssertTrue(auth.hasPrefix("Basic "),
                      "Authorization must use Basic scheme. Got: \(auth)")
    }

    func testIHateMoney_loadBills_basicAuthCredentialsAreCorrect() {
        // Verify the exact base64 encoding of "token:password".
        let project = Project.makeIHateMoney(token: "mytoken", password: "secret")
        MockURLProtocol.requestHandler = jsonHandler()

        let exp = expectation(description: "request intercepted")
        NetworkService.shared.loadBillsPublisher(project)
            .sink(receiveCompletion: { _ in exp.fulfill() }, receiveValue: { _ in })
            .store(in: &subscriptions)
        waitForExpectations(timeout: 2)

        guard let auth = MockURLProtocol.lastCapturedRequest?.value(forHTTPHeaderField: "Authorization"),
              auth.hasPrefix("Basic ") else { return }

        let base64 = String(auth.dropFirst("Basic ".count))
        guard let data = Data(base64Encoded: base64),
              let credentials = String(data: data, encoding: .utf8) else {
            return XCTFail("Authorization header base64 is malformed")
        }
        XCTAssertEqual(credentials, "mytoken:secret",
                       "Basic auth credentials must be '{token}:{password}'")
    }

    // MARK: - testProject() — status code passthrough

    func testProject_returns200OnSuccess() {
        let project = Project.makeCospend()
        MockURLProtocol.requestHandler = { req in
            (.ok(for: req.url!), Data())
        }

        let exp = expectation(description: "status received")
        NetworkService.shared.testProject(project)
            .sink { (_, code) in
                XCTAssertEqual(code, 200)
                exp.fulfill()
            }
            .store(in: &subscriptions)
        waitForExpectations(timeout: 2)
    }

    func testProject_returns401OnWrongCredentials() {
        let project = Project.makeCospend()
        MockURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }

        let exp = expectation(description: "401 received")
        NetworkService.shared.testProject(project)
            .sink { (_, code) in
                XCTAssertEqual(code, 401)
                exp.fulfill()
            }
            .store(in: &subscriptions)
        waitForExpectations(timeout: 2)
    }

    func testProject_returnsMinus1OnNetworkFailure() {
        // If the network is completely unreachable, testProject must return -1
        // (not crash, not hang) so the UI can show an appropriate error message.
        let project = Project.makeCospend()
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let exp = expectation(description: "error received as -1")
        NetworkService.shared.testProject(project)
            .sink { (_, code) in
                XCTAssertEqual(code, -1)
                exp.fulfill()
            }
            .store(in: &subscriptions)
        waitForExpectations(timeout: 2)
    }

    // MARK: - loadBills() — graceful empty result on error

    func testLoadBills_on404_failsWithNotFound() {
        let project = Project.makeCospend()
        MockURLProtocol.requestHandler = { req in
            (.notFound(for: req.url!), Data())
        }

        var received: LoadError?
        let exp = expectation(description: "publisher fails")

        NetworkService.shared.loadBillsPublisher(project)
            .sink(receiveCompletion: { completion in
                if case let .failure(error) = completion { received = error }
                exp.fulfill()
            }, receiveValue: { _ in
                XCTFail("no bills should arrive on 404")
            })
            .store(in: &subscriptions)

        waitForExpectations(timeout: 2)
        XCTAssertEqual(received, .notFound,
                       "a missing project has to reach the UI, not vanish into an empty list")
    }

    /// This used to emit `[:]`, which the UI could not tell apart from a project
    /// that genuinely has no members.
    func testLoadMembers_onNetworkFailure_failsWithConnection() {
        let project = Project.makeCospend()
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.timedOut)
        }

        var received: LoadError?
        let exp = expectation(description: "publisher fails")
        NetworkService.shared.loadMembersPublisher(project)
            .sink(receiveCompletion: { completion in
                if case let .failure(error) = completion { received = error }
                exp.fulfill()
            }, receiveValue: { _ in
                XCTFail("no members should arrive when the connection failed")
            })
            .store(in: &subscriptions)
        waitForExpectations(timeout: 2)
        XCTAssertEqual(received, .connection)
    }

    // MARK: - HTTP methods

    func testLoadBills_usesGET() {
        let project = Project.makeCospend()
        MockURLProtocol.requestHandler = jsonHandler()

        let exp = expectation(description: "request intercepted")
        NetworkService.shared.loadBillsPublisher(project)
            .sink(receiveCompletion: { _ in exp.fulfill() }, receiveValue: { _ in })
            .store(in: &subscriptions)
        waitForExpectations(timeout: 2)

        XCTAssertEqual(MockURLProtocol.lastCapturedRequest?.httpMethod, "GET")
    }

    func testLoadMembers_usesGET() {
        let project = Project.makeCospend()
        MockURLProtocol.requestHandler = jsonHandler()

        let exp = expectation(description: "request intercepted")
        NetworkService.shared.loadMembersPublisher(project)
            .sink(receiveCompletion: { _ in exp.fulfill() }, receiveValue: { _ in })
            .store(in: &subscriptions)
        waitForExpectations(timeout: 2)

        XCTAssertEqual(MockURLProtocol.lastCapturedRequest?.httpMethod, "GET")
    }

    // MARK: - Write operations: POST bill

    func testCospend_postBill_usesPOSTMethod() {
        // Creating a new expense must use POST
        ProjectManager.shared.currentProject = .makeCospend()
        MockURLProtocol.requestHandler = jsonHandler(status: 200, body: "{}")

        let exp = expectation(description: "request intercepted")
        NetworkService.shared.postBillPublisher(bill: .make())
            .sink(receiveCompletion: { _ in exp.fulfill() }, receiveValue: { _ in })
            .store(in: &subscriptions)
        waitForExpectations(timeout: 2)

        XCTAssertEqual(MockURLProtocol.lastCapturedRequest?.httpMethod, "POST",
                       "Creating a bill must use POST")
    }

    func testCospend_postBill_urlContainsBillsEndpoint() {
        // Cospend's bills endpoint is /bills at the end of the project path.
        // A missing or misspelled suffix causes a 404 with no user-visible error.
        ProjectManager.shared.currentProject = .makeCospend()
        MockURLProtocol.requestHandler = jsonHandler(status: 200, body: "{}")

        let exp = expectation(description: "request intercepted")
        NetworkService.shared.postBillPublisher(bill: .make())
            .sink(receiveCompletion: { _ in exp.fulfill() }, receiveValue: { _ in })
            .store(in: &subscriptions)
        waitForExpectations(timeout: 2)

        let url = MockURLProtocol.lastCapturedRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("/bills"), "POST bill URL must contain /bills. Got: \(url)")
    }

    func testCospend_postBill_paramsInQueryStringNotBody() {
        // Cospend receives bill params as URL query items, not a JSON body.
        // Sending a JSON body to Cospend would be silently ignored by the server.
        ProjectManager.shared.currentProject = .makeCospend()
        MockURLProtocol.requestHandler = jsonHandler(status: 200, body: "{}")

        let exp = expectation(description: "request intercepted")
        NetworkService.shared.postBillPublisher(bill: .make())
            .sink(receiveCompletion: { _ in exp.fulfill() }, receiveValue: { _ in })
            .store(in: &subscriptions)
        waitForExpectations(timeout: 2)

        XCTAssertNil(MockURLProtocol.lastCapturedRequest?.httpBody,
                     "Cospend POST must put params in the query string, not the body")
        let query = MockURLProtocol.lastCapturedRequest?.url?.query ?? ""
        XCTAssertFalse(query.isEmpty, "Cospend POST must include bill params as query items")
    }

    func testIHateMoney_postBill_sendsJSONBody() {
        // iHateMoney expects bill params as a JSON body with Content-Type: application/json.
        // Note: URLSession converts httpBody to httpBodyStream when routing through URLProtocol
        ProjectManager.shared.currentProject = .makeIHateMoney()
        MockURLProtocol.requestHandler = jsonHandler(status: 200, body: "{}")

        let exp = expectation(description: "request intercepted")
        NetworkService.shared.postBillPublisher(bill: .make())
            .sink(receiveCompletion: { _ in exp.fulfill() }, receiveValue: { _ in })
            .store(in: &subscriptions)
        waitForExpectations(timeout: 2)

        XCTAssertEqual(
            MockURLProtocol.lastCapturedRequest?.value(forHTTPHeaderField: "Content-Type"),
            "application/json",
            "iHateMoney POST must set Content-Type: application/json"
        )
        XCTAssertNil(
            MockURLProtocol.lastCapturedRequest?.url?.query,
            "iHateMoney POST must NOT put params in the URL query string"
        )
    }

    func testIHateMoney_postBill_returnsTrue_on201() {
        // iHateMoney returns 201 Created (not 200 OK) on successful bill creation.
        // NetworkService must treat any 2xx response as success.
        ProjectManager.shared.currentProject = .makeIHateMoney()
        MockURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!, Data())
        }

        let exp = expectation(description: "result received")
        NetworkService.shared.postBillPublisher(bill: .make())
            .sink { success in
                XCTAssertTrue(success, "201 Created must be treated as success")
                exp.fulfill()
            }
            .store(in: &subscriptions)
        waitForExpectations(timeout: 2)
    }

    // MARK: - Write operations: PUT / DELETE bill

    func testCospend_updateBill_usesPUTMethod() {
        // Updating an existing bill must use PUT. Using POST would create a duplicate.
        ProjectManager.shared.currentProject = .makeCospend()
        MockURLProtocol.requestHandler = jsonHandler(status: 200, body: "{}")

        let bill = Bill.make(id: 42)
        let exp = expectation(description: "request intercepted")
        NetworkService.shared.updateBillPublisher(bill: bill)
            .sink(receiveCompletion: { _ in exp.fulfill() }, receiveValue: { _ in })
            .store(in: &subscriptions)
        waitForExpectations(timeout: 2)

        XCTAssertEqual(MockURLProtocol.lastCapturedRequest?.httpMethod, "PUT",
                       "Updating a bill must use PUT")
        let url = MockURLProtocol.lastCapturedRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("/bills/42"),
                      "Update URL must include the bill id. Got: \(url)")
    }

    func testCospend_deleteBill_usesDELETEMethod() {
        // Deleting a bill must use DELETE with the bill id in the URL path.
        ProjectManager.shared.currentProject = .makeCospend()
        MockURLProtocol.requestHandler = jsonHandler(status: 200, body: "{}")

        let bill = Bill.make(id: 7)
        let exp = expectation(description: "request intercepted")
        NetworkService.shared.deleteBillPublisher(bill: bill)
            .sink(receiveCompletion: { _ in exp.fulfill() }, receiveValue: { _ in })
            .store(in: &subscriptions)
        waitForExpectations(timeout: 2)

        XCTAssertEqual(MockURLProtocol.lastCapturedRequest?.httpMethod, "DELETE",
                       "Deleting a bill must use DELETE")
        let url = MockURLProtocol.lastCapturedRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("/bills/7"),
                      "Delete URL must include the bill id. Got: \(url)")
    }

    // MARK: - Write operations: members

    func testCospend_createMember_usesPOSTToMembersEndpoint() {
        // Creating a new group member hits /members with POST.
        ProjectManager.shared.currentProject = .makeCospend()
        MockURLProtocol.requestHandler = jsonHandler(status: 200, body: "{}")

        let exp = expectation(description: "request intercepted")
        NetworkService.shared.createMemberPublisher(name: "Alice")
            .sink(receiveCompletion: { _ in exp.fulfill() }, receiveValue: { _ in })
            .store(in: &subscriptions)
        waitForExpectations(timeout: 2)

        XCTAssertEqual(MockURLProtocol.lastCapturedRequest?.httpMethod, "POST",
                       "Creating a member must use POST")
        let url = MockURLProtocol.lastCapturedRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(url.hasSuffix("/members") || url.contains("/members?"),
                      "Create member URL must end with /members. Got: \(url)")
    }

    // MARK: - getProjectName (async)

    func testGetProjectName_decodesServerProjectName() async throws {
        // getProjectName fetches the project's display name from the server and
        // returns a new Project with the server-provided name. This is how the
        // app resolves token-based share links where the human name is unknown.
        let project = Project.makeCospend(token: "mytoken", password: "mypass")
        MockURLProtocol.requestHandler = { req in
            let json = #"{"name": "Our Trip", "id": "mytoken"}"#.data(using: .utf8)!
            return (.ok(for: req.url!), json)
        }

        let result = try await NetworkService.shared.getProjectName(project)
        XCTAssertEqual(result.name, "Our Trip",
                       "getProjectName must use the server-returned name, not the token")
    }

    func testGetProjectName_throwsOnNonSuccessResponse() async {
        // A 404 response means the project token is invalid or the server can't
        // find the project. getProjectName must throw HTTPError.statuscode
        let project = Project.makeCospend()
        MockURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
        }

        do {
            _ = try await NetworkService.shared.getProjectName(project)
            XCTFail("getProjectName must throw on 404, not return silently")
        } catch {
            // Any thrown error is acceptable
        }
    }
}
