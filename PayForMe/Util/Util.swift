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

typealias ProjectData = (server: URL?, project: String?, passwd: String?)

extension URL {
    func decodeMoneyBusterString() -> ProjectData {
        guard absoluteString.hasPrefix("https://net.eneiluj.moneybuster.cospend/"),
              pathComponents.count >= 3, pathComponents.count <= 4 else { return (nil, nil, nil) }
        return (URL(string: "https://" + pathComponents[1]), pathComponents[2], pathComponents[safe: 3])
    }
}

extension URL {
    func decodeCospendString() -> ProjectData {
        guard let host = host,
              let scheme = scheme,
              scheme.localizedCaseInsensitiveContains("cospend")
        else {
            return (nil, nil, nil)
        }
        
        var hostString = "https://\(host)"
        
        if let port = port {hostString += ":\(port)"}
        
        if pathComponents.count > 3 {
            hostString += "/" + pathComponents[1..<(pathComponents.count - 2)].joined(separator: "/")
        }
        
        return (URL(string: hostString),
                pathComponents[safe: pathComponents.count - 2],
                pathComponents.last)
    }
}

extension URL {
    func decodeQRCode() -> ProjectData {
        guard let scheme = scheme else { return (nil, nil, nil) }
        return scheme.contains("cospend") ? decodeCospendString() : decodeMoneyBusterString()
    }
}

// Why is URL an identifier but not identifiable?
extension URL: Identifiable {
    public var id: URL {
        self
    }
}
