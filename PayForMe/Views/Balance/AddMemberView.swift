//
//  AddMemberView.swift
//  PayForMe
//
//  Created by Camille Mainz on 04.03.20.
//

import SwiftUI

struct AddMemberView: View {
    @Binding
    var memberName: String

    var addMemberAction: () -> Void
    var cancelButtonAction: () -> Void

    var cancelButtonWidth: CGFloat = 10

    var body: some View {
        VStack(alignment: .center) {
            HStack(alignment: .center) {
                EmptyView()
                Spacer()
                Text("Add member")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.trailing, -cancelButtonWidth)
                Spacer()
                Button(action: cancelButtonAction, label: { Image(systemName: "xmark.circle.fill") })
                    .frame(width: cancelButtonWidth, height: cancelButtonWidth, alignment: .center)
            }
            TextField("Member name", text: $memberName)
                .multilineTextAlignment(.center)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            FancyButton(add: false, action: addMemberAction, text: "Submit")
        }
        .padding()
    }
}

struct AddMemberView_Previews: PreviewProvider {
    static var previews: some View {
        AddMemberView(memberName: .constant("Lel"), addMemberAction: {}, cancelButtonAction: {})
    }
}
