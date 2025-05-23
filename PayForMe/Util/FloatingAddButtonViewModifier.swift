//
//  FloatingAddButtonViewModifier.swift
//  PayForMe
//
//  Created by Max Tharr on 03.10.20.
//

import SwiftUI

struct FloatingAddButtonViewModifier: ViewModifier {
    @State private var sheetToggle = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $sheetToggle) {
                AddBillView(showModal: $sheetToggle)
            }
            .overlay(FloatingAddButtonView(sheetToggle: $sheetToggle).padding(10), alignment: .bottom)
    }
}

private struct FloatingAddButtonView: View {
    @Binding var sheetToggle: Bool
    
    let size = 70.0

    var body: some View {
        Button(action: {
            sheetToggle.toggle()
        }) {
            Label("Add Bill", systemImage: "bag.badge.plus")
                .padding(10)
                .font(.headline)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(20)
                    .shadow(radius: /*@START_MENU_TOKEN@*/8/*@END_MENU_TOKEN@*/)
                    
            }
        
        .accessibility(identifier: "Add Bill")
        .accessibility(label: Text("Add Bill"))
    }
}

struct FloatingAddButtonViewModifier_Previews: PreviewProvider {
    static var previews: some View {
        FloatingAddButtonView(sheetToggle: .constant(true))
        let viewModel = BillListViewModel()
        previewProject.members = previewPersons
        viewModel.currentProject = previewProject
        previewProjects.forEach { project in
            try? ProjectManager.shared.addProject(project)
        }
        ProjectManager.shared.currentProject = previewProject

        //return NavigationView {
        return TabView {
            BillList(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "rectangle.stack")
                }
            BillList(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "arrow.right.arrow.left")
                }
            BillList(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "gear")
                }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.dark)
    }
}
