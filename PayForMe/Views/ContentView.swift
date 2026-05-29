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
    }

    var tabBar: some View {
        TabView(selection: $tabBarIndex) {
            BillList(viewModel: billListViewModel)
                .tabItem {
                    Image(systemName: "rectangle.stack")
                }
                .tag(tabBarItems.BillList)
            BalanceList(viewModel: balanceViewModel)
                .tabItem {
                    Image(systemName: "arrow.right.arrow.left")
                }
                .tag(tabBarItems.Balance)
            ProjectList()
                .tabItem {
                    Image(systemName: "gear")
                }
                .tag(tabBarItems.ServerList)
        }
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
