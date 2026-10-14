//
//  TextMatchUtils.swift
//  PayForMe
//

import Foundation

/// Text-matching helpers for the title → category suggestion. Pure functions, no UI or network.
enum TextMatchUtils {
    /// Folds ä/ö/ü/ß to ae/oe/ue/ss so ASCII-typed and native spellings match, then reduces
    /// everything that is not a-z/0-9 to single spaces.
    static func normalize(_ text: String) -> String {
        let folded = text.lowercased()
            .replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ü", with: "ue")
            .replacingOccurrences(of: "ß", with: "ss")
        var result = ""
        var lastWasSpace = true
        for scalar in folded.unicodeScalars {
            let isAlphanumeric = (scalar >= "a" && scalar <= "z") || (scalar >= "0" && scalar <= "9")
            if isAlphanumeric {
                result.unicodeScalars.append(scalar)
                lastWasSpace = false
            } else if !lastWasSpace {
                result.append(" ")
                lastWasSpace = true
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    static func tokenize(_ text: String) -> [String] {
        let normalized = normalize(text)
        return normalized.isEmpty ? [] : normalized.components(separatedBy: " ")
    }

    /// Word-boundary-safe phrase containment: a raw substring check would match keyword "gas"
    /// inside "Gaststätte".
    static func containsTokenSequence(_ haystack: [String], _ needle: [String]) -> Bool {
        guard !needle.isEmpty, needle.count <= haystack.count else { return false }
        for start in 0 ... (haystack.count - needle.count)
            where Array(haystack[start ..< start + needle.count]) == needle {
            return true
        }
        return false
    }
}
