//
//  UrlExtensionsTests.swift
//  PayForMeTests
//
//  Tests for the URL extensions that decode deep-link and QR-code URLs into
//  (server, project, password) triples.
//
//  WHY THIS MATTERS:
//  The app is launched from two URL schemes and one web URL pattern:
//
//    cospend://                                — native Cospend deep link (iOS)
//    https://net.eneiluj.moneybuster.cospend/  — MoneyBuster web share link (Android)
//
//  Both are also used as QR-code payloads. `decodeQRCode()` dispatches to the
//  correct decoder based on the URL scheme. If the routing is wrong, the user
//  scans a QR code and lands in the wrong decoder — producing nil for all three
//  fields, and the "Add Project" form stays empty with no error message.
//
//  URL parsing bugs are especially insidious because they produce no network
//  request and no visible error — just a blank form.
//

@testable import PayForMe
import XCTest

class UrlExtensionsTests: XCTestCase {

    // MARK: - cospend:// deep link decoding

    func testCospendStringDecoding() throws {
        // Simplest form: host maps directly to the server root.
        // cospend://host/project/password → server="https://host"
        let url = URL(string: "cospend://myserver.de/myproject/no-pass")!

        let (server, project, password) = url.decodeCospendString()
        XCTAssertEqual(server?.absoluteString, "https://myserver.de")
        XCTAssertEqual(project, "myproject")
        XCTAssertEqual(password, "no-pass")
    }

    func testCospendStringDecodingForSubfolders() throws {
        // Nextcloud is often installed in a subfolder (e.g. example.com/nc/).
        // Extra path components belong to the server URL, not the project name.
        // cospend://host/folder1/folder2/project/password
        // → server="https://host/folder1/folder2"
        let url = URL(string: "cospend://myserver.de/folder1/folder2/myproject/mypassword")!

        let (server, project, password) = url.decodeCospendString()
        XCTAssertEqual(server?.absoluteString, "https://myserver.de/folder1/folder2")
        XCTAssertEqual(project, "myproject")
        XCTAssertEqual(password, "mypassword")
    }

    func testCospendStringDecodingForSubdomains() throws {
        // Subdomain servers must be decoded correctly — the full hostname is the
        // server root, not just the top-level domain.
        let url = URL(string: "cospend://subdomain.myserver.de/myproject/mypassword")!

        let (server, project, password) = url.decodeCospendString()
        XCTAssertEqual(server?.absoluteString, "https://subdomain.myserver.de")
        XCTAssertEqual(project, "myproject")
        XCTAssertEqual(password, "mypassword")
    }

    func testCospendStringDecodingForNonStandardPort() throws {
        // Self-hosted Nextcloud instances often run on a non-standard port.
        // The port must be preserved in the decoded server URL so API calls
        // reach the right endpoint.
        let url = URL(string: "cospend://myserver.de:1234/myproject/mypassword")!

        let (server, project, password) = url.decodeCospendString()
        XCTAssertEqual(server?.absoluteString, "https://myserver.de:1234")
        XCTAssertEqual(project, "myproject")
        XCTAssertEqual(password, "mypassword")
    }

    func testCospendError_wrongScheme() throws {
        // decodeCospendString() requires a scheme that contains "cospend".
        // A plain https:// URL must return nil for all three values — even if
        // its path looks like it might contain project data.
        let url = URL(string: "https://myserver/myproject/mypassword")!

        let (server, project, password) = url.decodeCospendString()
        XCTAssertNil(server)
        XCTAssertNil(project)
        XCTAssertNil(password)
    }

    // MARK: - MoneyBuster web link decoding

    func testMoneyBusterDecoding() throws {
        // MoneyBuster share links encode the real server as the first path component
        // after the fixed host prefix. The full structure is:
        // https://net.eneiluj.moneybuster.cospend/{server}/{project}/{password}
        let url = URL(string: "https://net.eneiluj.moneybuster.cospend/myserver.de/myproject/mypassword")!

        let (server, project, password) = url.decodeMoneyBusterString()
        XCTAssertEqual(server?.absoluteString, "https://myserver.de")
        XCTAssertEqual(project, "myproject")
        XCTAssertEqual(password, "mypassword")
    }

    func testMoneyBusterNoPassword() throws {
        // MoneyBuster omits the password component for passwordless projects.
        // The decoder must return nil for password without crashing — the default
        // "no-pass" value is set by AddProjectManualViewModel, not here.
        let url = URL(string: "https://net.eneiluj.moneybuster.cospend/myserver.de/myproject")!

        let (server, project, password) = url.decodeMoneyBusterString()
        XCTAssertEqual(server?.absoluteString, "https://myserver.de")
        XCTAssertEqual(project, "myproject")
        XCTAssertNil(password)
    }

    func testMoneyBusterError_wrongHost() throws {
        // An https:// URL that does NOT use the MoneyBuster host prefix must return
        // nil. Without this guard, any https URL would decode as a project link.
        let url = URL(string: "https://myserver/myproject/mypassword")!

        let (server, project, password) = url.decodeMoneyBusterString()
        XCTAssertNil(server)
        XCTAssertNil(project)
        XCTAssertNil(password)
    }

    func testMoneyBusterDecoding_tooManyPathComponents_returnsNil() throws {
        // The decoder guards: pathComponents.count must be 3 or 4.
        // (["", server, project] = 3, or + password = 4)
        // URLs with more components are malformed — the server/project boundary
        // is ambiguous, so all three fields must be nil.
        let url = URL(string: "https://net.eneiluj.moneybuster.cospend/server/project/password/extra")!

        let (server, project, password) = url.decodeMoneyBusterString()
        XCTAssertNil(server)
        XCTAssertNil(project)
        XCTAssertNil(password)
    }

    // MARK: - QR code dispatcher (decodeQRCode)

    func testDecodeQRCode_cospendSchemeRoutesToCospendDecoder() throws {
        // decodeQRCode() dispatches based on scheme: if the scheme contains
        // "cospend", it calls decodeCospendString(). The result must match
        // a direct call to decodeCospendString() for the same URL.
        let url = URL(string: "cospend://myserver.de/myproject/mypassword")!

        let (server, project, password) = url.decodeQRCode()
        XCTAssertEqual(server?.absoluteString, "https://myserver.de")
        XCTAssertEqual(project, "myproject")
        XCTAssertEqual(password, "mypassword")
    }

    func testDecodeQRCode_httpsSchemeRoutesToMoneyBusterDecoder() throws {
        // For https:// QR codes, decodeQRCode() must call decodeMoneyBusterString().
        // A MoneyBuster QR code uses https:// with the fixed MoneyBuster host prefix.
        let url = URL(string: "https://net.eneiluj.moneybuster.cospend/myserver.de/myproject/mypassword")!

        let (server, project, password) = url.decodeQRCode()
        XCTAssertEqual(server?.absoluteString, "https://myserver.de")
        XCTAssertEqual(project, "myproject")
        XCTAssertEqual(password, "mypassword")
    }
}
