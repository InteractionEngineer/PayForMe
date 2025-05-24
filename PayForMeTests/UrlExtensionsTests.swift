//
//  UrlExtensionsTests.swift
//  PayForMeTests
//
//  Created by Max Tharr on 08.11.20.
//

@testable import PayForMe
import XCTest

class UrlExtensionsTests: XCTestCase {
    func testCospendStringDecoding() throws {
        let url = URL(string: "cospend://myserver.de/myproject/no-pass")!

        let (server, project, password) = url.decodeCospendString()
        XCTAssertNotNil(server)
        XCTAssertNotNil(project)
        XCTAssertNotNil(password)

        if let server = server, let password = password, let project = project {
            XCTAssertEqual(server.absoluteString, "https://myserver.de")
            XCTAssertEqual(project, "myproject")
            XCTAssertEqual(password, "no-pass")
        }
    }

    func testCospendStringDecodingForSubfolders() throws {
        let url = URL(string: "cospend://myserver.de/folder1/folder2/myproject/mypassword")!

        let (server, project, password) = url.decodeCospendString()
        XCTAssertNotNil(server)
        XCTAssertNotNil(project)
        XCTAssertNotNil(password)

        if let server = server, let password = password, let project = project {
            XCTAssertEqual(server.absoluteString, "https://myserver.de/folder1/folder2")
            XCTAssertEqual(project, "myproject")
            XCTAssertEqual(password, "mypassword")
        }
    }

    func testCospendStringDecodingForSubdomains() throws {
        let url = URL(string: "cospend://subdomain.myserver.de/myproject/mypassword")!

        let (server, project, password) = url.decodeCospendString()
        XCTAssertNotNil(server)
        XCTAssertNotNil(project)
        XCTAssertNotNil(password)

        if let server = server, let password = password, let project = project {
            XCTAssertEqual(server.absoluteString, "https://subdomain.myserver.de")
            XCTAssertEqual(project, "myproject")
            XCTAssertEqual(password, "mypassword")
        }
    }

    func testCospendStringDecodingForNonStandardPort() throws {
        let url = URL(string: "cospend://myserver.de:1234/myproject/mypassword")!

        let (server, project, password) = url.decodeCospendString()
        XCTAssertNotNil(server)
        XCTAssertNotNil(project)
        XCTAssertNotNil(password)

        if let server = server, let password = password, let project = project {
            XCTAssertEqual(server.absoluteString, "https://myserver.de:1234")
            XCTAssertEqual(project, "myproject")
            XCTAssertEqual(password, "mypassword")
        }
    }

    func testCospendError() throws {
        let url = URL(string: "https://myserver/myproject/mypassword")!

        let (server, project, password) = url.decodeCospendString()

        XCTAssertNil(server)
        XCTAssertNil(project)
        XCTAssertNil(password)
    }

    func testMoneyBusterError() throws {
        let url = URL(string: "https://myserver/myproject/mypassword")!

        let (server, project, password) = url.decodeMoneyBusterString()
        XCTAssertNil(server)
        XCTAssertNil(project)
        XCTAssertNil(password)
    }

    func testMoneyBusterDecoding() throws {
        let url = URL(string: "https://net.eneiluj.moneybuster.cospend/myserver.de/myproject/mypassword")!

        let (server, project, password) = url.decodeMoneyBusterString()
        XCTAssertNotNil(server)
        XCTAssertNotNil(project)
        XCTAssertNotNil(password)

        if let server = server, let password = password, let project = project {
            XCTAssertEqual(server.absoluteString, "https://myserver.de")
            XCTAssertEqual(password, "mypassword")
            XCTAssertEqual(project, "myproject")
        }
    }

    func testMoneyBusterNoPassword() throws {
        let url = URL(string: "https://net.eneiluj.moneybuster.cospend/myserver.de/myproject")!

        let (server, project, password) = url.decodeMoneyBusterString()
        XCTAssertNotNil(server)
        XCTAssertNotNil(project)
        XCTAssertNil(password)

        if let server = server, let project = project {
            XCTAssertEqual(server.absoluteString, "https://myserver.de")
            XCTAssertEqual(project, "myproject")
        }
    }
}
