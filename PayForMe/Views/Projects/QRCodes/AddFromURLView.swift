//
//  AddFromURLView.swift
//  PayForMe
//
//  Created by Max Tharr on 08.11.20.
//

import SlickLoadingSpinner
import SwiftUI

struct AddFromURLView: View {
    @ObservedObject var viewmodel: AddProjectQRViewModel
    var body: some View {
        viewmodel.askForPassword ?
            AddPasswordView(password: $viewmodel.passwordText, connectionState: viewmodel.isProject, name: viewmodel.name, urlString: viewmodel.urlString).eraseToAnyView()
            : loadingView.eraseToAnyView()
    }

    var loadingView: some View {
        VStack {
            SlickLoadingSpinner(connectionState: viewmodel.isProject)
        }
        .padding(40)
    }
}

struct AddFromURLView_Previews: PreviewProvider {
    static var previews: some View {
        AddFromURLView(viewmodel: AddProjectQRViewModel(openedByURL: URL(string: "cospend://myserver.de/myproject/mypassword")!))
    }
}
