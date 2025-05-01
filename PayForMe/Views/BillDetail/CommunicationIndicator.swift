//
//  CommunicationIndicator.swift
//  PayForMe
//
//  Created by Max Tharr on 25.02.20.
//

import SwiftUI

struct CommunicationIndicator: View {
    var body: some View {
        ZStack {
            RadialGradient(gradient: Gradient(colors: [Color.white, Color.gray]), center: /*@START_MENU_TOKEN@*/ .center/*@END_MENU_TOKEN@*/, startRadius: /*@START_MENU_TOKEN@*/5/*@END_MENU_TOKEN@*/, endRadius: /*@START_MENU_TOKEN@*/500/*@END_MENU_TOKEN@*/)
                .scaleEffect(1.5)
                .opacity(0.5)
            LoadingRings()
        }
    }
}

struct CommunicationIndicator_Previews: PreviewProvider {
    static var previews: some View {
        CommunicationIndicator()
    }
}

struct LoadingRings: View {
    @State var spin3D_x = false
    @State var spin3D_y = false
    @State var spin3D_xy = false

    var body: some View {
        ZStack {
            Circle() // Large circle
                .stroke(lineWidth: 5)
                .frame(width: 100, height: 100)
                .foregroundColor(.red)
                .rotation3DEffect(.degrees(spin3D_x ? 180 : 1), axis: (x: spin3D_x ? 1 : 0, y: 0, z: 0))
                .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false))
                .onAppear {
                    self.spin3D_x.toggle()
                }
            Circle() // Middle circle
                .stroke(lineWidth: 5)
                .frame(width: 60, height: 60)
                .foregroundColor(.green)
                .rotation3DEffect(.degrees(spin3D_y ? 360 : 1), axis: (x: 0, y: spin3D_y ? 1 : 0, z: 0))
                .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false))
                .onAppear {
                    self.spin3D_y.toggle()
                }
            Circle() // Inner Circle
                .stroke(lineWidth: 5)
                .frame(width: 20, height: 20)
                .foregroundColor(.blue)
                .rotation3DEffect(.degrees(spin3D_xy ? 180 : 1), axis: (x: spin3D_xy ? 0 : 1, y: spin3D_xy ? 0 : 1, z: 0))
                .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false))
                .onAppear {
                    self.spin3D_xy.toggle()
                }
        }
    }
}
