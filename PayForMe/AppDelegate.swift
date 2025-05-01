//
//  AppDelegate.swift
//  PayForMe
//
//  Created by Max Tharr on 21.01.20.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    static var isUITestingEnabled: Bool {
        return ProcessInfo.processInfo.arguments.contains("UI-Testing")
    }

    static var isUITestingOnboarding: Bool {
        return ProcessInfo.processInfo.arguments.contains("Onboarding")
    }

    private func setStateForUITesting() {
        if AppDelegate.isUITestingEnabled {
            if AppDelegate.isUITestingOnboarding {
                ProjectManager.shared.prepareUITestOnboarding()
            } else {
                try! ProjectManager.shared.prepareUITest()
            }
        }
    }

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        setStateForUITesting()
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options _: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_: UIApplication, didDiscardSceneSessions _: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}
