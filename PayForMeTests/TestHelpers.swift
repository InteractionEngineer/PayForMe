//
//  TestHelpers.swift
//  PayForMeTests
//
//  Shared test infrastructure: a mock URL protocol for intercepting network
//  requests without hitting real servers, plus reusable test fixtures.
//

import Foundation
import XCTest
@testable import PayForMe

// MARK: - MockURLProtocol
//
// How it works:
//   URLSession routes every request through registered URLProtocol subclasses
//   before sending it over the network. By registering MockURLProtocol we get
//   to inspect and short-circuit every request made during a test.
//
// Usage in a test class:
//
//   override func setUp() {
//       URLProtocol.registerClass(MockURLProtocol.self)
//       MockURLProtocol.requestHandler = { request in
//           let response = HTTPURLResponse(url: request.url!, statusCode: 200, ...)!
//           return (response, myJSON)
//       }
//   }
//
//   override func tearDown() {
//       URLProtocol.unregisterClass(MockURLProtocol.self)
//       MockURLProtocol.reset()
//   }
//

class MockURLProtocol: URLProtocol {

    // Set this before each test to control what the mock returns.
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    // Read this after the publisher fires to assert on the outgoing request.
    static var lastCapturedRequest: URLRequest?

    static func reset() {
        requestHandler = nil
        lastCapturedRequest = nil
    }

    // Claim every request so nothing leaks to the real network.
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.lastCapturedRequest = request

        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Project fixtures

extension Project {
    static func makeCospend(
        token: String = "mytoken",
        password: String = "mypass",
        url: String = "https://nextcloud.example.com",
        projectId: String = "my-project"
    ) -> Project {
        Project(
            name: "test-project",
            password: password,
            token: token,
            backend: .cospend,
            url: URL(string: url)!,
            projectId: projectId,
        )
    }

    static func makeIHateMoney(
        token: String = "mytoken",
        password: String = "mypass",
        url: String = "https://ihatemoney.org",
        projectId: String = "my-project"
    ) -> Project {
        Project(
            name: "test-project",
            password: password,
            token: token,
            backend: .iHateMoney,
            url: URL(string: url)!,
            projectId: projectId
        )
    }
}

// MARK: - Person fixtures

let testAlice = Person(id: 1, weight: 1, name: "Alice", activated: true)
let testBob   = Person(id: 2, weight: 1, name: "Bob",   activated: true)
let testCarla = Person(id: 3, weight: 1, name: "Carla", activated: true)

// MARK: - Bill fixtures

extension Bill {
    static func make(
        id: Int = 1,
        amount: Double = 30.0,
        what: String = "Dinner",
        dateString: String = "2026-05-14",
        payerId: Int = 1,
        owers: [Person] = [testAlice, testBob, testCarla],
        repeat: String? = "n",
        lastchanged: Int? = nil
    ) -> Bill {
        Bill(
            id: id,
            amount: amount,
            what: what,
            date: DateFormatter.cospend.date(from: dateString)!,
            payer_id: payerId,
            owers: owers,
            repeat: `repeat`,
            lastchanged: lastchanged
        )
    }
}

// MARK: - HTTPURLResponse convenience

extension HTTPURLResponse {
    static func ok(for url: URL) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
    }
    static func notFound(for url: URL) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
    }

    static func status(_ code: Int, for url: URL) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)!
    }
}
