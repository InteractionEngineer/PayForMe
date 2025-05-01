//
//  PersonsView.swift
//  PayForMe
//
//  Created by Max Tharr on 25.02.20.
//

import SwiftUI

struct PersonsView: View {
    @Binding
    var bill: Bill

    @Binding
    var members: [Int: Person]

    var body: some View {
        HStack(spacing: 5) {
            payerText()
            Image(systemName: "arrow.right")
            owersTexts()
        }.font(.headline)
    }

    func payerText() -> some View {
        PersonText(person: payer)
    }

    func owersTexts() -> some View {
        HStack(spacing: 1) {
            ForEach(bill.owers) {
                ower in
                PersonText(person: self.realPerson(ower))
                //                if self.bill.owers.last != ower {
                //                    Text(", ")
                //                }
            }
        }.padding(0)
    }

    func realPerson(_ ower: Person) -> Person {
        guard let person = members[ower.id] else {
            return ower
        }
        return person
    }

    var payer: Person {
        members[bill.payer_id] ?? Person(id: 1, weight: 1, name: "Unknown", activated: true)
    }
}

struct PersonsView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = BillListViewModel()
        viewModel.currentProject = previewProject
        return BillList(viewModel: viewModel)
    }
}
