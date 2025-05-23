//
//  PersonText.swift
//  PayForMe
//
//  Created by Max Tharr on 20.02.20.
//

import SwiftUI

struct PersonText: View {
    @State
    var person: Person

    var body: some View {
        Text(person.name)
            .padding(2)
            .background(colorOfPerson(person))
            .foregroundColor(Color.white)
            .cornerRadius(5)
            .lineLimit(1)
    }

    func colorOfPerson(_ person: Person) -> Color {
        guard let color = person.color else {
            return Color.standardColorById(id: person.id)
        }

        return Color(color)
    }
}

struct PersonText_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = BillListViewModel()
        previewProject.bills = previewBills
        previewProject.members = previewPersons
        viewModel.currentProject = previewProject
        return BillList(viewModel: viewModel)
    }
}
