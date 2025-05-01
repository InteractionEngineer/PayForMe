//
//  BillCell.swift
//  PayForMe
//
//  Created by Max Tharr on 22.01.20.
//

import SwiftUI

struct BillCell: View {
    @ObservedObject
    var viewModel: BillListViewModel

    @State
    var bill: Bill

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Text(bill.what).font(.headline)
                PersonsView(bill: $bill, members: $viewModel.currentProject.members)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 10) {
                Text(amountString()).font(.headline)
                Text(DateFormatter.cospend.string(from: bill.date)).font(.subheadline)
            }
        }
    }

    func amountString() -> String {
        return "\(String(format: "%.2f", bill.amount))"
    }
}

struct BillCell_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = BillListViewModel()
        previewProject.bills = previewBills
        previewProject.members = previewPersons
        viewModel.currentProject = previewProject
        return BillList(viewModel: viewModel)
    }
}
