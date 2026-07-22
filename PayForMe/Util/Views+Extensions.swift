//
//  Views+Extensions.swift
//  PayForMe
//
//  Created by Max Tharr on 03.10.20.
//

import Foundation
import SwiftUI

extension View {
    /// Fallback-Look für prominente Aktions-Buttons vor iOS 26 (kein Liquid Glass verfügbar).
    func fancyStyle(active: Bool = true) -> some View {
        padding(10)
            .background(active ? Color.accentColor : Color.secondary)
            .foregroundColor(.white)

            .cornerRadius(10)
            .shadow(color: (active ? Color.accentColor : Color.secondary).opacity(0.5), radius: 4, x: 2, y: 2)
    }

    /// Prominenter Aktions-Button: System-Liquid-Glass ab iOS 26, sonst der bisherige `fancyStyle`.
    @ViewBuilder
    func prominentActionStyle(active: Bool = true) -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.fancyStyle(active: active)
        }
    }

    /// Lässt die Tab-Bar beim Scrollen einklappen (Liquid-Glass-Verhalten). No-op vor iOS 26.
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

    /// Kreisförmiger Glass-Hintergrund für einen Button. Ab iOS 26 echtes Liquid Glass,
    /// sonst ein Accent-Kreis mit Schatten (analog altem Floating-Button).
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

    /// Legt einen schwebenden, kreisförmigen Aktions-Button unten rechts über den Inhalt
    /// (über der Tab-Bar, à la Apple Music). Daumen-erreichbar.
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

/// Schwebender, kreisförmiger Haupt-Aktions-Button (Liquid Glass ab iOS 26).
struct GlassActionButton: View {
    let systemImage: String
    let accessibilityLabel: LocalizedStringKey
    var accessibilityIdentifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .frame(width: 56, height: 56)
        }
        .glassCircleStyle()
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}
