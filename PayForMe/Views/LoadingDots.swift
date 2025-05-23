//
//  LoadingDots.swift
//  PayForMe
//
//  Created by Max Tharr on 25.02.20.
//

import SwiftUI

struct LoadingDots: View {
    @State private var leftAnimates = false
    @State private var middleAnimates = false
    @State private var rightAnimates = false

    var body: some View {
        // Middle
        HStack {
            // Left
            Circle()
                .stroke(lineWidth: 3)
                .frame(width: 12, height: 12)
                .scaleEffect(leftAnimates ? 1 : 0)
                .animation(Animation.spring().repeatForever(autoreverses: false).speed(0.5))
                .onAppear {
                    self.leftAnimates.toggle()
                }

            Circle()
                .stroke(lineWidth: 3)
                .frame(width: 12, height: 12)
                .scaleEffect(middleAnimates ? 1 : 0)
                .animation(Animation.spring().repeatForever(autoreverses: false).speed(0.5).delay(0.15))
                .onAppear {
                    self.middleAnimates.toggle()
                }

            // Right
            Circle()
                .stroke(lineWidth: 3)
                .frame(width: 12, height: 12)
                .scaleEffect(rightAnimates ? 1 : 0)
                .animation(Animation.spring().repeatForever(autoreverses: false).speed(0.5).delay(0.25))
                .onAppear {
                    self.rightAnimates.toggle()
                }
            Circle()
                .stroke(lineWidth: 3)
                .frame(width: 12, height: 12)
                .scaleEffect(rightAnimates ? 1 : 0)
                .animation(Animation.spring().repeatForever(autoreverses: false).speed(0.5).delay(0.35))
                .onAppear {
                    self.rightAnimates.toggle()
                }
            Circle()
                .stroke(lineWidth: 3)
                .frame(width: 12, height: 12)
                .scaleEffect(rightAnimates ? 1 : 0)
                .animation(Animation.spring().repeatForever(autoreverses: false).speed(0.5).delay(0.45))
                .onAppear {
                    self.rightAnimates.toggle()
                }
        }
    }
}

struct LoadingDots_Previews: PreviewProvider {
    static var previews: some View {
        LoadingDots()
    }
}
