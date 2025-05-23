//
//  WhoPaidView.swift
//  PayForMe
//
//  Created by Max Tharr on 26.01.20.
//

import SwiftUI

struct WhoPaidView: View {
    @State
    var members: [Person]

    @Binding
    var selectedPayer: Int

    var body: some View {
        if members.count <= 4 {
            return AnyView(Picker(selection: $selectedPayer, label: Text("Payer")) {
                ForEach(members) {
                    member in
                    Text(member.name)
                }
            }.pickerStyle(SegmentedPickerStyle()))
        } else {
            return AnyView(
                Picker(selection: $selectedPayer, label: Text("Payer")) {
                    ForEach(members) {
                        member in
                        PersonText(person: member)
                    }
                }.pickerStyle(DefaultPickerStyle()))
        }
    }
}

struct WhoPaidView_Previews: PreviewProvider {
    static var previews: some View {
        return WhoPaidView(members: Array(previewPersons.values), selectedPayer: .constant(1))
    }
}
