//
//  Views+Extensions.swift
//  PayForMe
//
//  Created by Max Tharr on 03.10.20.
//

import Foundation
import SwiftUI

extension View {
    func fancyStyle(active: Bool = true) -> some View {
        padding(10)
            .background(active ? Color.accentColor : Color.secondary)
            .foregroundColor(.white)

            .cornerRadius(10)
            .shadow(color: (active ? Color.accentColor : Color.secondary).opacity(0.5), radius: 4, x: 2, y: 2)
    }

    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }

    func addFloatingAddButton() -> some View {
        modifier(FloatingAddButtonViewModifier())
    }
}
