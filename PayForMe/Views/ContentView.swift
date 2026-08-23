//
//  ContentView.swift
//  PayForMe
//
//  Created by Max Tharr on 21.01.20.
//

import Foundation
import SwiftUI

struct ContentView: View {
    @ObservedObject
    var manager = ProjectManager.shared

    @StateObject
    private var billListViewModel = BillListViewModel()

    @StateObject
    private var balanceViewModel = BalanceViewModel()

    @Environment(\.scenePhase)
    private var scenePhase

    @State
    var tabBarIndex = tabBarItems.BillList

    @State
    var showModal = false

    @State
    var hidePlusButton = false

    var body: some View {
        ZStack {
            if !manager.projects.isEmpty {
                tabBar
            } else {
                OnboardingView()
            }
        }
        .sheet(item: $manager.openedByURL) { url in
            AddFromURLView(viewmodel: AddProjectQRViewModel(openedByURL: url))
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active && !manager.projects.isEmpty {
                manager.loadBillsAndMembers()
            }
        }
        // Without this the app just shows empty lists when the server turns us
        // away — the complaint behind #37.
        .alert(item: $manager.loadingError) { error in
            Alert(title: Text("Could not load project"),
                  message: Text(Self.message(for: error)),
                  dismissButton: .default(Text("OK")))
        }
    }

    static func message(for error: LoadError) -> String {
        switch error {
        case .unauthorized:
            return NSLocalizedString("load_error_unauthorized", comment: "Loading failed because the credentials were rejected")
        case .notFound:
            return NSLocalizedString("load_error_not_found", comment: "Loading failed because the project does not exist on the server")
        case .connection:
            return NSLocalizedString("load_error_connection", comment: "Loading failed because the server could not be reached")
        case .invalidResponse:
            return NSLocalizedString("load_error_invalid_response", comment: "Loading failed because the server's answer could not be read")
        case let .http(code):
            return String(format: NSLocalizedString("load_error_generic", comment: "Loading failed with an HTTP status code"), code)
        }
    }

    var tabBar: some View {
        TabView(selection: $tabBarIndex) {
            BillList(viewModel: billListViewModel)
                .tabItem {
                    Label("Bills", systemImage: "rectangle.stack")
                }
                .tag(tabBarItems.BillList)
            BalanceList(viewModel: balanceViewModel)
                .tabItem {
                    Label("Members", systemImage: "arrow.right.arrow.left")
                }
                .tag(tabBarItems.Balance)
            ProjectList()
                .tabItem {
                    Label("Projects", systemImage: "gear")
                }
                .tag(tabBarItems.ServerList)
        }
        .glassTabBarMinimize()
    }
}

enum tabBarItems: Int {
    case ServerList
    case BillList
    case Balance
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        previewProjects.forEach {
            try! ProjectManager.shared.addProject($0)
        }
        ProjectManager.shared.currentProject = previewProject
        return ContentView()
    }
}
