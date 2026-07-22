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

    @State private var showAddProject = false
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
            .navigationTitle("Projects")
            .glassActionButton(systemImage: "folder",
                               accessibilityLabel: "Add project",
                               accessibilityIdentifier: "Add project") {
                showAddProject = true
            }
            .sheet(isPresented: $showAddProject) {
                AddProjectManualView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    func deleteProject(at offsets: IndexSet) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
            for index in offsets {
                manager.deleteProject(manager.projects[index])
            }
        }
    }
}

struct ServerList_Previews: PreviewProvider {
    static var previews: some View {
        return ProjectList()
    }
}
