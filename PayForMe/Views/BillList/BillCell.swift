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

    let bill: Bill

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Text(bill.what).font(.headline)
                PersonsView(bill: bill, members: viewModel.currentProject.members)
                tagLine
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 10) {
                Text(amountString()).font(.headline)
                Text(DateFormatter.cospend.string(from: bill.date)).font(.subheadline)
            }
        }
    }

    private var category: CospendTag? {
        viewModel.currentProject.category(for: bill)
    }

    private var paymentMode: CospendTag? {
        viewModel.currentProject.paymentMode(for: bill)
    }

    @ViewBuilder
    private var tagLine: some View {
        if let tagText = tagText {
            tagText
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var tagText: Text? {
        switch (category, paymentMode) {
        case let (category?, paymentMode?):
            return Text(category.label) + Text(verbatim: " · ") + Text(paymentMode.label)
        case let (category?, nil):
            return Text(category.label)
        case let (nil, paymentMode?):
            return Text(paymentMode.label)
        case (nil, nil):
            return nil
        }
    }

    func amountString() -> String {
        return "\(String(format: "%.2f", bill.amount))"
    }
}

struct BillCell_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = BillListViewModel()
        previewProject.bills = previewBills.enumerated().map { index, bill in
            guard index < 2 else { return bill }
            var tagged = bill
            tagged.categoryid = previewCategories[index].id
            tagged.paymentmodeid = previewPaymentModes[index].id
            return tagged
        }
        previewProject.members = previewPersons
        previewProject.categories = previewCategories
        previewProject.paymentModes = previewPaymentModes
        viewModel.currentProject = previewProject
        return BillList(viewModel: viewModel)
    }
}
