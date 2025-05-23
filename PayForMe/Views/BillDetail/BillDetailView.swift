//
//  AddBillView.swift
//  PayForMe
//
//  Created by Max Tharr on 23.01.20.
//

import Combine
import Foundation
import SlickLoadingSpinner
import SwiftUI

struct BillDetailView: View {
    @Environment(\.presentationMode)
    var presentationMode: Binding<PresentationMode>

    @Binding
    var showModal: Bool

    @ObservedObject
    var viewModel: BillDetailViewModel

    var navBarTitle = LocalizedStringKey("Add Bill")
    var sendButtonTitle = LocalizedStringKey("Create Bill")

    @State
    var noneAllToggle = 1

    @State
    var sendBillButtonDisabled = true

    @State
    var sendingInProgress = LoadingState.notStarted

    var body: some View {
        VStack {
            Form {
                Section(header: Text("Payer")) {
                    WhoPaidView(members: Array(viewModel.currentProject.members.values).sorted{ $0.name < $1.name }, selectedPayer: self.$viewModel.selectedPayer).onAppear {
                        if self.viewModel.currentProject.members[self.viewModel.selectedPayer] == nil {
                            guard let id = self.viewModel.currentProject.members.first?.key else { return }
                            self.viewModel.selectedPayer = id
                        }
                    }
                    TextField("What was paid", text: self.$viewModel.topic)
                    TextField("How much", text: self.$viewModel.amount).keyboardType(.decimalPad)
                }
                Section(header: Text("Date")) {
                    DatePicker(selection: self.$viewModel.billDate, displayedComponents: [.date]) {
                        Label("Bill date", systemImage: "calendar").labelStyle(.iconOnly)
                    }
                }
                Section(header: Text("Owers")) {
                    PotentialOwersView(vm: viewModel.povm)
                }
            }
            FancyLoadingButton(isLoading: sendingInProgress, add: false, action: self.sendBillToServer, text: showModal ? "Create Bill" : "Update Bill")
                .disabled(sendBillButtonDisabled)
                .onReceive(self.viewModel.validatedInput) {
                    self.sendBillButtonDisabled = !$0
                }
                .padding()
        }
        .navigationBarTitle(navBarTitle, displayMode: .inline)
    }

    func sendBillToServer() async {
        guard let newBill = viewModel.createBill() else {
            print("Could not create bill")
            return
        }
        sendingInProgress = .connecting
        await ProjectManager.shared.saveBill(newBill)
        sendingInProgress = .success
        ProjectManager.shared.loadBillsAndMembers()
        showModal.toggle()
        DispatchQueue.main.async {
            self.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct BillDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = BillDetailViewModel(currentBill: previewBills[0])
        vm.currentProject = previewProject
        return BillDetailView(showModal: .constant(true), viewModel: vm)
    }
}
