//
//  FancyBotton.swift
//  PayForMe
//
//  Created by Camille Mainz on 24.02.20.
//

import SlickLoadingSpinner
import SwiftUI

struct FancyLoadingButton: View {
    @Environment(\.isEnabled) private var isEnabled: Bool

    let isLoading: LoadingState

    var add: Bool

    var action: () -> Void
    var text: String

    var body: some View {
        switch isLoading {
        case .notStarted:
            return Button(action: action) {
                if add {
                    Image(systemName: "plus")
                } else {
                    Text(LocalizedStringKey(text))
                }
            }
            .fancyStyle(active: self.isEnabled)
            .disabled(!isEnabled)
            .eraseToAnyView()
        default:
            return SlickLoadingSpinner(connectionState: isLoading)
                .frame(width: 50, height: 50)
                .eraseToAnyView()
        }
    }
}

struct FancyBotton_Previews: PreviewProvider {
    static var previews: some View {
        FancyLoadingButton(isLoading: .connecting, add: false, action: ({}), text: "Add Project").environment(\.locale, .init(identifier: "de"))
    }
}
