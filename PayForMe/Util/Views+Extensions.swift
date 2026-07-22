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

    @ViewBuilder
    func prominentActionStyle(active: Bool = true) -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.fancyStyle(active: active)
        }
    }

    @ViewBuilder
    func glassTabBarMinimize() -> some View {
        if #available(iOS 26, *) {
            self.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }

    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }

    @ViewBuilder
    func glassCircleStyle() -> some View {
        if #available(iOS 26, *) {
            self
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
        } else {
            self
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(Circle())
                .shadow(radius: 8)
        }
    }

    func glassActionButton(systemImage: String,
                           accessibilityLabel: LocalizedStringKey,
                           accessibilityIdentifier: String? = nil,
                           action: @escaping () -> Void) -> some View {
        overlay(alignment: .bottomTrailing) {
            GlassActionButton(systemImage: systemImage,
                              accessibilityLabel: accessibilityLabel,
                              accessibilityIdentifier: accessibilityIdentifier,
                              action: action)
                .padding(.trailing, 20)
                .padding(.bottom, 20)
        }
    }
}

/// The plus is composited as a separate badge rather than using the `.badge.plus` symbol variant,
/// which sits in a different spot per symbol.
struct GlassActionButton: View {
    let systemImage: String
    let accessibilityLabel: LocalizedStringKey
    var accessibilityIdentifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .overlay(alignment: .bottomLeading) { plusBadge }
                .frame(width: 56, height: 56)
        }
        .glassCircleStyle()
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }

    private var plusBadge: some View {
        Image(systemName: "plus")
            .font(.system(size: 8, weight: .black))
            .foregroundStyle(Color.accentColor)
            .padding(3)
            .background(.white, in: Circle())
            .offset(x: -4, y: 4)
    }
}
