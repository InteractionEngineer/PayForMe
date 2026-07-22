//
//  BalanceList.swift
//  PayForMe
//
//  Created by Max Tharr on 29.01.20.
//

import SwiftUI

struct BalanceList: View {
    @ObservedObject
    var viewModel: BalanceViewModel

    @State
    var addingUser = false

    @State
    var memberName = ""

    @State
    private var memberAddError: MemberAddError?

    var body: some View {
        NavigationView {
            list
                .navigationTitle("Members")
                .glassActionButton(systemImage: "person.fill",
                                   accessibilityLabel: "Add member",
                                   accessibilityIdentifier: "Add member") {
                    showAddUser()
                }
                .sheet(isPresented: $addingUser) {
                    AddMemberView(memberName: $memberName, addMemberAction: submitUser, cancelButtonAction: cancelAddUser)
                        .alert(item: $memberAddError) { error in
                            Alert(title: Text("Could not add member"),
                                  message: Text(memberErrorMessage(for: error.code)),
                                  dismissButton: .default(Text("OK")))
                        }
                }
        }.navigationViewStyle(StackNavigationViewStyle())
    }

    @ViewBuilder
    var list: some View {
        List {
            ForEach(viewModel.balances.sorted(by: balanceSort(_:_:))) {
                balance in
                if balance.amount < 0 {
                    NavigationLink(destination: BillDetailView(showModal: .constant(false), viewModel: BillDetailViewModel(currentBill: self.createSettlingBill(balance: balance)))) {
                        BalanceCell(balance: balance)
                    }
                } else {
                    BalanceCell(balance: balance)
                }
            }
        }
        .refreshable {
            await ProjectManager.shared.refresh()
        }
    }

    func balanceSort(_ a: Balance, _ b: Balance) -> Bool {
        (a.amount > b.amount) || ((a.amount == b.amount) && (a.person.name < b.person.name))
    }

    func showAddUser() {
        addingUser = true
    }

    func submitUser() {
        ProjectManager.shared.addMember(memberName) { statusCode in
            if (200 ... 299).contains(statusCode) {
                self.addingUser = false
                self.memberName = ""
                ProjectManager.shared.loadBillsAndMembers()
            } else {
                // Keep the sheet open so the user keeps their input and can retry.
                self.memberAddError = MemberAddError(code: statusCode)
            }
        }
    }

    private func memberErrorMessage(for code: Int) -> String {
        switch code {
        case 401, 403:
            return NSLocalizedString("member_error_forbidden", comment: "Member add failed due to insufficient rights")
        case -1:
            return NSLocalizedString("member_error_network", comment: "Member add failed due to a network error")
        default:
            return String(format: NSLocalizedString("member_error_generic", comment: "Member add failed with HTTP status code"), code)
        }
    }

    func cancelAddUser() {
        memberName = ""
        addingUser = false
    }

    func createSettlingBill(balance: Balance) -> Bill {
        let ower = viewModel.balances.sorted(by: { $0.amount > $1.amount })[0]
        let payer = balance.person
        let topic = "Settling balance for \(balance.person.name)"
        let amount = ower.amount.magnitude < balance.amount.magnitude ? ower.amount : balance.amount.magnitude
        return Bill(id: -1, amount: amount, what: topic, date: Date(), payer_id: payer.id, owers: [ower.person], repeat: "n")
    }
}

struct MemberAddError: Identifiable {
    let code: Int
    var id: Int { code }
}

struct BalanceList_Previews: PreviewProvider {
    static var previews: some View {
        let vm = BalanceViewModel()
        vm.currentProject = previewProject
        vm.setBalances()
        return BalanceList(viewModel: vm, addingUser: false)
    }
}

struct BalanceCell: View {
    let balance: Balance

    var body: some View {
        HStack {
            PersonText(person: balance.person)
            Spacer()
            Text(" \(String(format: "%.2f", balance.amount))")
                .font(.headline)
                .foregroundColor(balance.amount >= 0 ? Color.primary : Color.red)
        }.padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
    }
}
