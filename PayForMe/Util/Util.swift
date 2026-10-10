//
//  Util.swift
//  PayForMe
//
//  Created by Camille Mainz on 28.01.20.
//

import Foundation
import SlickLoadingSpinner
import SwiftUI

extension Collection {
    /// Returns the element at the specified index iff it is within bounds, otherwise nil.
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension Color {
    init(_ pc: PersonColor) {
        self.init(red: Double(pc.r) / 255, green: Double(pc.g) / 255, blue: Double(pc.b) / 255, opacity: 1)
    }

    static var PFMBackground: Color {
        if UIScreen.main.traitCollection.userInterfaceStyle == .dark {
            return Color.black
        } else {
            return Color(UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0))
        }
    }

    static func standardColorById(id: Int) -> Color {
        let colors = [
            rgb(88, 86, 214),
            rgb(52, 170, 220),
            rgb(90, 200, 250),
            rgb(76, 217, 100),
            rgb(255, 59, 48),
            rgb(255, 59, 48),
            rgb(255, 149, 0),
            rgb(255, 204, 0),
        ]
        return colors[id % colors.count]
    }

    private static func rgb(_ r: Int, _ g: Int, _ b: Int) -> Color {
        Color(red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0, opacity: 1)
    }
}

extension String {
    var isValidURL: Bool {
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        if let match = detector.firstMatch(in: self, options: [], range: NSRange(location: 0, length: utf16.count)) {
            return (match.range.length == utf16.count) && (contains("https://") || contains("http://"))
        }
        return false
    }

    /// The project id iHateMoney derives from a project's name: NFKD-normalised,
    /// stripped of everything that is not a word character, whitespace or a
    /// hyphen, lowercased, with runs of hyphens and whitespace collapsed into a
    /// single hyphen.
    ///
    /// Users only ever see the name — the id is not shown anywhere in the web UI
    /// — but the API is addressed by the id. A name typed into the add-project
    /// form therefore has to be converted the same way the server converts it.
    /// Mirrors `slugify()` in `ihatemoney/utils.py`.
    var iHateMoneyProjectId: String {
        let withoutPunctuation = decomposedStringWithCompatibilityMapping.unicodeScalars.filter { scalar in
            switch scalar.properties.generalCategory {
            case .nonspacingMark, .spacingMark, .enclosingMark:
                // The diacritics NFKD just split off. Dropping them is what
                // turns "Café" into "cafe" rather than "cafe\u{301}".
                return false
            default:
                return CharacterSet.alphanumerics.contains(scalar)
                    || scalar == "_"
                    || scalar == "-"
                    || CharacterSet.whitespacesAndNewlines.contains(scalar)
            }
        }

        let normalised = String(String.UnicodeScalarView(withoutPunctuation))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        var result = ""
        var lastWasSeparator = false
        for character in normalised {
            if character == "-" || character.isWhitespace {
                if !lastWasSeparator {
                    result.append("-")
                }
                lastWasSeparator = true
            } else {
                result.append(character)
                lastWasSeparator = false
            }
        }
        return result
    }

    var isValidEmail: Bool {
        // here, `try!` will always succeed because the pattern is valid
        let regex = try! NSRegularExpression(pattern: "^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$", options: .caseInsensitive)
        return regex.firstMatch(in: self, options: [], range: NSRange(location: 0, length: count)) != nil
    }
}

extension JSONDecoder {
    convenience init(dateFormatter: DateFormatter) {
        self.init()
        dateDecodingStrategy = .formatted(dateFormatter)
    }
}

extension JSONEncoder {
    convenience init(dateFormatter: DateFormatter) {
        self.init()
        dateEncodingStrategy = .formatted(dateFormatter)
    }
}

extension DateFormatter {
    static let cospend: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter
    }()
}

struct TextFieldContainer: UIViewRepresentable {
    private var placeholder: String
    private var text: Binding<String>

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self.text = text
    }

    func makeCoordinator() -> TextFieldContainer.Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: UIViewRepresentableContext<TextFieldContainer>) -> UITextField {
        let innertTextField = UITextField(frame: .zero)
        innertTextField.keyboardType = .URL
        innertTextField.autocorrectionType = .no
        innertTextField.autocapitalizationType = .none
        innertTextField.placeholder = placeholder
        innertTextField.text = text.wrappedValue
        innertTextField.delegate = context.coordinator

        context.coordinator.setup(innertTextField)

        return innertTextField
    }

    func updateUIView(_ uiView: UITextField, context _: UIViewRepresentableContext<TextFieldContainer>) {
        uiView.text = text.wrappedValue
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: TextFieldContainer

        init(_ textFieldContainer: TextFieldContainer) {
            parent = textFieldContainer
        }

        func setup(_ textField: UITextField) {
            textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        }

        @objc func textFieldDidChange(_ textField: UITextField) {
            parent.text.wrappedValue = textField.text ?? ""

            let newPosition = textField.endOfDocument
            textField.selectedTextRange = textField.textRange(from: newPosition, to: newPosition)
        }
    }
}

extension StringProtocol {
    func index<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.lowerBound
    }

    func endIndex<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.upperBound
    }

    func indices<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Index] {
        var indices: [Index] = []
        var startIndex = self.startIndex
        while startIndex < endIndex,
              let range = self[startIndex...]
              .range(of: string, options: options)
        {
            indices.append(range.lowerBound)
            startIndex = range.lowerBound < range.upperBound ? range.upperBound :
                index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return indices
    }

    func ranges<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var startIndex = self.startIndex
        while startIndex < endIndex,
              let range = self[startIndex...]
              .range(of: string, options: options)
        {
            result.append(range)
            startIndex = range.lowerBound < range.upperBound ? range.upperBound :
                index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
}

protocol ProjectData {
    var server: URL { get }
    var project: String { get }
}

struct ProjectDataWithToken: ProjectData {
    var server: URL
    var project: String
    var token: String
}

struct ProjectDataWithPassword: ProjectData {
    var server: URL
    var project: String
    var password: String?
}

extension URL {
    func decodeMoneyBusterString() -> ProjectDataWithPassword? {
        guard absoluteString.hasPrefix("https://net.eneiluj.moneybuster.cospend/"),
              pathComponents.count >= 3, pathComponents.count <= 4 else {
            return nil
        }

        guard let hostUrl = URL(string: "https://" + pathComponents[1]) else {
            return nil
        }

        let password = pathComponents[safe: 3]

        return ProjectDataWithPassword(
            server: hostUrl,
            project: pathComponents[2],
            password: password
        )
    }

    func decodeCospendString() -> ProjectDataWithPassword? {
        guard let host = host,
              let scheme = scheme,
              scheme.localizedCaseInsensitiveContains("cospend")
        else {
            return nil
        }

        var hostString = host

        if let port = port {hostString += ":\(port)"}

        if pathComponents.count > 3 {
            hostString += "/" + pathComponents[1..<(pathComponents.count - 2)].joined(separator: "/")
        }

        guard
            let hostUrl = URL(string: "https://" + hostString),
            let project = pathComponents[safe: pathComponents.count - 2],
            let password = pathComponents.last
        else { return nil }

        return ProjectDataWithPassword(
            server: hostUrl,
            project: project,
            password: password)
    }

    func decodeIHateMoneyString() -> ProjectDataWithToken? {
        guard let host = host, let scheme = scheme, scheme.localizedCaseInsensitiveContains("ihatemoney") else {
            return nil
        }

        let hostUrl = "https://" + host

        guard
            let url = URL(string: hostUrl),
            let project = pathComponents[safe: pathComponents.count - 3],
            let token = pathComponents.last
        else { return nil}

        return ProjectDataWithToken(server: url, project: project, token: token)
    }

    func decodeQRCode() -> ProjectData? {
        guard let scheme = scheme else { return nil }
        if scheme.contains("cospend") {
            return decodeCospendString()
        } else if scheme.contains("ihatemoney") {
            return decodeIHateMoneyString()
        } else {
            return decodeMoneyBusterString()
        }
    }
}

extension URL: Identifiable {
    // Why is URL an identifier but not identifiable?
    public var id: URL {
        self
    }
}
