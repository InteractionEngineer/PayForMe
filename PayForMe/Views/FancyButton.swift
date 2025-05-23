//
//  FancyButton.swift
//  PayForMe
//
//  Created by Max Tharr on 03.10.20.
//

import SwiftUI

struct FancyButton: View {
    @Environment(\.isEnabled) private var isEnabled: Bool

    var add: Bool

    var action: () -> Void
    var text: String

    var body: some View {
        return Button(action: action) {
            if add {
                Image(systemName: "plus")
            } else {
                Text(LocalizedStringKey(text))
            }
        }
        .fancyStyle(active: self.isEnabled)
        .disabled(!isEnabled)
    }
}

struct FancyButton_Previews: PreviewProvider {
    static var previews: some View {
        FancyButton(add: false, action: {}, text: "Test")
    }
}
