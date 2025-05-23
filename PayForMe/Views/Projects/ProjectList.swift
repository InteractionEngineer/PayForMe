//
//  ServerList.swift
//  PayForMe
//
//  Created by Max Tharr on 22.01.20.
//

import AVFoundation
import SwiftUI

struct ProjectList: View {
    @ObservedObject
    var manager = ProjectManager.shared

    @State private var addProject: AddingProjectMethod?
    @State private var shareProject: Project?

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(manager.projects) { project in
                        ProjectListEntry(project: project, currentProject: manager.currentProject, shareProject: self.$shareProject)
                    }
                    .onDelete(perform: deleteProject)
                }
                .sheet(item: $shareProject) { project in
                    ShareProjectQRCode(project: project)
                }
            }
            .navigationBarTitle("Projects")
            .navigationBarItems(trailing:
                HStack {
                    Button(action: {
                        self.addProject = .manual
                    }) {
                        Image(systemName: "plus").fancyStyle()
                    }
                    Button(action: {
                        self.addProject = .qrCode
                    }) {
                        Image(systemName: "qrcode").fancyStyle()
                    }
                }
                .sheet(item: $addProject, content: { method -> AnyView in
                    switch method {
                    case .qrCode:
                        return destination.eraseToAnyView()
                    case .manual:
                        return AddProjectManualView().eraseToAnyView()
                    }
                })
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private enum AddingProjectMethod: Int, CaseIterable, Identifiable {
        var id: Int {
            switch self {
            case .qrCode: return 0
            case .manual: return 1
            }
        }

        case qrCode
        case manual
    }

    func deleteProject(at offsets: IndexSet) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
            for index in offsets {
                manager.deleteProject(manager.projects[index])
            }
        }
    }

    var destination: some View {
        ProjectQRPermissionCheckerView()
    }
}

struct ServerList_Previews: PreviewProvider {
    static var previews: some View {
        return ProjectList()
    }
}
