//
//  ProjectListEntry.swift
//  PayForMe
//
//  Created by Max Tharr on 08.02.23.
//  Copyright © 2023 Mayflower GmbH. All rights reserved.
//

import SwiftUI

struct ProjectListEntry: View {
    let project: Project
    let manager = ProjectManager.shared
    let currentProject: Project

    @Binding var shareProject: Project?

    @State var edit = false
    @State var me = 0
    
    func actionShare(project: Project) {
        guard let data = URL(string: "\(project.url)/apps/cospend/s/\(project.token)") else { return }
        let av = UIActivityViewController(activityItems: [data.absoluteString], applicationActivities: nil)
        UIApplication.shared.connectedScenes.flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
            .first { $0.isKeyWindow }?.rootViewController!.present(av, animated: true)
    }

    var body: some View {
        Button(action: {
            self.manager.setCurrentProject(project)
        }, label: {
            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text(project.name)
                            .allowsTightening(true)
                            .lineLimit(1)
                        Text(project.backend == .cospend ? "Cospend" : "iHateMoney").font(.caption).foregroundColor(Color.gray)
                    }
                    Spacer()
                    if project == currentProject {
                        Button(action: {
                            self.edit.toggle()
                        }, label: {
                            Image(systemName: "pencil")
                        })
                        .padding(.trailing, 8)
                    }
                    if project.backend == .cospend {
                        Button(action: {
                            actionShare(project: project)
                        }, label: {
                            Image(systemName: "square.and.arrow.up")
                        })
                        .padding(.trailing, 8)
                        Button(action: {
                            self.shareProject = project
                        }, label: {
                            Image(systemName: "qrcode")
                        })
                    }
                }
                .foregroundColor(self.currentProject == project ? .accentColor : .primary)
            }
            if edit {
                VStack(alignment: .leading) {
                    Text("Add a default payer for new bills (e.g. yourself)")
                        .font(.caption)
                        .foregroundColor(.primary)
                    WhoPaidView(members: Array(project.members.values), selectedPayer: self.$me)
                }
            }
        })
        .onAppear {
            me = project.me ?? 0
        }
        .onChange(of: me) { newValue in
            project.me = newValue
            manager.updateProject(project: project)
            edit = false
        }
    }
}

struct ProjectListEntry_Previews: PreviewProvider {
    static var previews: some View {
        previewProject.members = previewManyPersons
        return List {
            ProjectListEntry(project: previewProject, currentProject: previewProject, shareProject: .constant(nil))
        }
    }
}
