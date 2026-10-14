//
//  CategoryChip.swift
//  PayForMe
//

import SwiftUI

/// A category or payment mode as a small rounded tag: icon and name on a soft tint of the tag's
/// own color (neutral when the server sent none). The one place tags are drawn in lists.
struct CategoryChip: View {
    let tag: CospendTag

    var body: some View {
        Text(tag.label)
            .font(.caption)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.18), in: Capsule())
    }

    private var tint: Color {
        guard let rgb = tag.rgb else { return Color.secondary }
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}

struct CategoryChip_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            CategoryChip(tag: previewCategories[0])
            CategoryChip(tag: previewPaymentModes[0])
            CategoryChip(tag: CospendTag(id: 1, name: "No color", color: "", icon: "🐕", order: 0))
        }
        .padding()
    }
}
