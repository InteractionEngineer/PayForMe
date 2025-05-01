//
//  BillsList.swift
//  PayForMe
//
//  Created by Max Tharr on 26.01.20.
//

import SwiftUI

struct BillList: View {
    @ObservedObject
    var viewModel: BillListViewModel

    @State
    var deleteAlert: IndexSet?

    var body: some View {
        NavigationView {
            List {
                iOS15ListContent
            }
            .addFloatingAddButton()
            .id(viewModel.currentProject.bills)
            .navigationBarTitle("Bills")
            .alert(item: $deleteAlert) { index in
                Alert(title: Text("Delete Bill"),
                      message: Text("Do you really want to erase the bill from the server?"),
                      primaryButton: .destructive(Text("Sure")) {
                          self.deleteBill(at: index)
                      },
                      secondaryButton: .cancel())
            }
            .listStyle(InsetGroupedListStyle())
        }
        .onAppear {
            ProjectManager.shared.loadBillsAndMembers()
        }
    }

    @ViewBuilder
    var iOS15ListContent: some View {
        Section(header: Picker("Sort by", selection: $viewModel.sortBy) {
            Text("Expense date").tag(BillListViewModel.SortedBy.expenseDate)
            Text("Changed date").tag(BillListViewModel.SortedBy.changedDate)
        }.pickerStyle(SegmentedPickerStyle())) {
            ForEach(viewModel.sortedBills) { bill in
                NavigationLink(destination:
                    BillDetailView(showModal: .constant(false),
                                   viewModel: BillDetailViewModel(currentBill: bill),
                                   navBarTitle: "Edit Bill",
                                   sendButtonTitle: "Update Bill")) {
                    BillCell(viewModel: self.viewModel, bill: bill)
                }
            }
            .onDelete(perform: {
                offset in
                self.deleteAlert = offset
            })
        }
    }

    func deleteBill(at offsets: IndexSet) {
        for offset in offsets {
            guard let bill = viewModel.sortedBills[safe: offset] else {
                return
            }
            ProjectManager.shared.deleteBill(bill, completion: {
                ProjectManager.shared.loadBillsAndMembers()
            })
        }
    }
}

extension IndexSet: Identifiable {
    public var id: Int {
        hashValue
    }
}

struct BillList_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = BillListViewModel()
        previewProject.bills = previewBills
        previewProject.members = previewPersons
        viewModel.currentProject = previewProject
        return BillList(viewModel: viewModel)
    }
}
