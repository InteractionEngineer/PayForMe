//
//  AppSettings.swift
//  PayForMe
//

import Foundation

/// App-wide user preferences stored in `UserDefaults`.
enum AppSettings {
    /// Suggest a bill category from its title. Off by default so existing behaviour is unchanged.
    static let autoCategoryKey = "autoCategoryEnabled"

    static var autoCategoryEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: autoCategoryKey) }
        set { UserDefaults.standard.set(newValue, forKey: autoCategoryKey) }
    }
}
