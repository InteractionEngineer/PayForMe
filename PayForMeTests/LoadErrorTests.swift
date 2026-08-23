//
//  LoadErrorTests.swift
//  PayForMeTests
//
//  Changing a project's password on the server left the app showing empty
//  lists and no explanation — #37. The cause was structural: both load
//  publishers declared `Never` as their failure type, so every failure had to
//  be turned into a value before it could leave NetworkService. An HTTP 401 was
//  dropped by a `compactMap` and a URLError became `[]`, which is exactly what
//  a project with no members looks like.
//
//  These tests pin down that a failure now reaches the caller as a failure.
//

import Combine
import XCTest
@testable import PayForMe

final class LoadErrorTests: XCTestCase {

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

    /// Runs a load against a stubbed response and returns how it ended.
    private func failure(loading load: (Project) -> AnyPublisher<[Bill], LoadError>,
                         status: Int,
                         body: String = "[]",
                         file: StaticString = #filePath,
                         line: UInt = #line) -> LoadError? {
        MockURLProtocol.requestHandler = { request in
            (.status(status, for: request.url!), Data(body.utf8))
        }

        var received: LoadError?
        let exp = expectation(description: "publisher finished")
        load(Project.makeCospend())
            .sink(receiveCompletion: { completion in
                if case let .failure(error) = completion { received = error }
                exp.fulfill()
            }, receiveValue: { _ in })
            .store(in: &subscriptions)
        waitForExpectations(timeout: 2)
        return received
    }

    // MARK: The case from the issue

    /// The password was changed on the server: Cospend answers 401, and until
    /// now that was indistinguishable from a project with no bills.
    func testRejectedCredentialsReachTheCaller() {
        XCTAssertEqual(failure(loading: NetworkService.shared.loadBillsPublisher, status: 401),
                       .unauthorized)
    }

    func testForbiddenCountsAsRejectedCredentials() {
        XCTAssertEqual(failure(loading: NetworkService.shared.loadBillsPublisher, status: 403),
                       .unauthorized)
    }

    // MARK: The other outcomes

    func testAnUnexpectedStatusIsPassedThroughVerbatim() {
        XCTAssertEqual(failure(loading: NetworkService.shared.loadBillsPublisher, status: 500),
                       .http(500))
    }

    /// A 200 whose body is not what we expect — pointing the app at something
    /// that is not a Cospend or iHateMoney server.
    func testAnUnreadableBodyIsAnInvalidResponse() {
        XCTAssertEqual(failure(loading: NetworkService.shared.loadBillsPublisher,
                               status: 200, body: "<html>hello</html>"),
                       .invalidResponse)
    }

    func testMembersFailTheSameWay() {
        MockURLProtocol.requestHandler = { request in
            (.status(401, for: request.url!), Data("[]".utf8))
        }

        var received: LoadError?
        let exp = expectation(description: "publisher finished")
        NetworkService.shared.loadMembersPublisher(Project.makeCospend())
            .sink(receiveCompletion: { completion in
                if case let .failure(error) = completion { received = error }
                exp.fulfill()
            }, receiveValue: { _ in
                XCTFail("no members should arrive on 401")
            })
            .store(in: &subscriptions)
        waitForExpectations(timeout: 2)
        XCTAssertEqual(received, .unauthorized)
    }

    // MARK: Status-code mapping

    func testStatusCodesMapToTheRightCase() {
        XCTAssertEqual(LoadError(statusCode: 401), .unauthorized)
        XCTAssertEqual(LoadError(statusCode: 403), .unauthorized)
        XCTAssertEqual(LoadError(statusCode: 404), .notFound)
        XCTAssertEqual(LoadError(statusCode: 503), .http(503))
    }

    // MARK: What the user is told

    /// Every case needs a message, and it has to be a translated one. A missing
    /// entry in Localizable.strings makes NSLocalizedString hand back the key
    /// itself, which would ship as "load_error_unauthorized" on screen.
    func testEveryErrorHasATranslatedMessage() {
        let errors: [LoadError] = [.unauthorized, .notFound, .connection, .invalidResponse, .http(500)]
        var messages = Set<String>()

        for error in errors {
            let message = ContentView.message(for: error)
            XCTAssertFalse(message.isEmpty, "\(error) has no message")
            XCTAssertFalse(message.hasPrefix("load_error_"),
                           "\(error) falls back to the raw key — the string is missing from Localizable.strings")
            messages.insert(message)
        }

        XCTAssertEqual(messages.count, errors.count,
                       "each error needs its own message, otherwise they are not worth distinguishing")
    }
}
