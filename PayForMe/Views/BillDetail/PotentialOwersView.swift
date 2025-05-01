//
//  PotentialOwersView.swift
//  PayForMe
//
//  Created by Max Tharr on 24.02.20.
//

import SwiftUI

struct PotentialOwersView: View {
    @ObservedObject
    var vm: PotentialOwersViewModel

    var body: some View {
        VStack {
            Picker(selection: $vm.owingStatus, label: Text("")) {
                Text("None").tag(1)
                Text("All").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            ForEach(vm.isOwing.indices, id: \.self) {
                index in
                Toggle(isOn: self.$vm.isOwing[index]) {
                    Text(self.vm.members[index].name)
                }
            }
        }
    }
}

struct PotentialOwersView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = PotentialOwersViewModel(members: previewPersons)
        return PotentialOwersView(vm: vm)
    }
}
