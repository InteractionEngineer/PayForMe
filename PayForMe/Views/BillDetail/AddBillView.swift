//
//  AddBillView.swift
//  PayForMe
//
//  Created by Camille Mainz on 13.02.20.
//

import SwiftUI

struct AddBillView: View {
    @Binding
    var showModal: Bool

    var body: some View {
        NavigationView {
            BillDetailView(showModal: $showModal, viewModel: BillDetailViewModel(currentBill: Bill.newBill()), navBarTitle: "Add Bill")
        }
    }
}

// struct AddBillView_Previews: PreviewProvider {
//    static var previews: some View {
//        AddBillView()
//    }
// }
