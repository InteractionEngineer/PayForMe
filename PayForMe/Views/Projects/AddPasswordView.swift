//
//  AddPasswordView.swift
//  PayForMe
//
//  Created by Max Tharr on 08.11.20.
//

import SlickLoadingSpinner
import SwiftUI

struct AddPasswordView: View {
    @Binding var password: String
    let connectionState: LoadingState

    let name: String
    let urlString: String

    var body: some View {
        VStack(spacing: 10) {
            Text(urlString).font(.title)
            Text(name).font(.title)
            SecureField("Type password here", text: $password)
                .font(.title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            SlickLoadingSpinner(connectionState: connectionState)
                .frame(width: 100, height: 100)
        }.padding(40)
    }
}

struct AddPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        AddPasswordView(password: .constant(""), connectionState: .connecting, name: "Test", urlString: "myserver.de")
    }
}
