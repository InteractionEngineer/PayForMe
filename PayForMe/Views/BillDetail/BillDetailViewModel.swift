//
//  BillDetailViewModel.swift
//  PayForMe
//
//  Created by Max Tharr on 24.02.20.
//

import Combine
import Foundation
import SwiftUI

class BillDetailViewModel: ObservableObject {
    var manager = ProjectManager.shared
    var cancellable: Cancellable?

    @Published
    var topic = ""

    @Published
    var amount = ""

    @Published
    var selectedPayer = 0

    @Published
    var currentProject: Project = demoProject

    @Published
    var currentBill: Bill
    
    @Published
    var billDate: Date = Date()

    @Published
    var selectedCategoryId = 0

    @Published
    var selectedPaymentModeId = 0

    var povm: PotentialOwersViewModel

    /// Read at suggestion time so toggling the setting applies to the next keystroke.
    var autoCategoryEnabled: () -> Bool = { AppSettings.autoCategoryEnabled }

    /// Once the user picks a category themself, titles no longer change it.
    private var categoryChosenByUser = false
    /// The current selection came from a suggestion and may be replaced by a newer one.
    private var categorySuggested = false
    private var topicCancellable: AnyCancellable?

    init(currentBill: Bill) {
        self.currentBill = currentBill
        povm = PotentialOwersViewModel(members: ProjectManager.shared.currentProject.members)

        manager.$currentProject.assign(to: &$currentProject)

        prefillData()

        // Only new bills get suggestions; an existing bill keeps the category it was saved with.
        if currentBill.id == -1 {
            topicCancellable = $topic.dropFirst().removeDuplicates().sink { [weak self] in
                self?.suggestCategory(for: $0)
            }
        }
    }

    func suggestCategory(for title: String) {
        guard autoCategoryEnabled(), !categoryChosenByUser else { return }
        let suggestion = CategoryClassifier.suggestCategoryId(title: title, in: currentProject.pickableCategories)
        if let suggestion = suggestion {
            selectedCategoryId = suggestion
            categorySuggested = true
        } else if categorySuggested {
            // The title moved away from the keyword that triggered the suggestion.
            selectedCategoryId = 0
            categorySuggested = false
        }
    }

    var validatedInput: AnyPublisher<Bool, Never> {
        return Publishers.CombineLatest3($topic, validatedAmount, povm.anyOwers)
            .map { topic, validatedAmount, anyOwers in
                !topic.isEmpty && validatedAmount && anyOwers
            }
            .eraseToAnyPublisher()
    }

    var validatedAmount: AnyPublisher<Bool, Never> {
        return $amount.map { amount in
            let safeAmount = amount.replacingOccurrences(of: ",", with: ".")
            return Double(safeAmount) != nil
        }
        .eraseToAnyPublisher()
    }

    var categoryPickerSelection: Binding<Int> {
        Binding(
            get: { self.currentProject.listedCategoryId(self.selectedCategoryId) },
            set: {
                self.categoryChosenByUser = true
                self.selectedCategoryId = $0
            }
        )
    }

    var paymentModePickerSelection: Binding<Int> {
        Binding(
            get: { self.currentProject.listedPaymentModeId(self.selectedPaymentModeId) },
            set: { self.selectedPaymentModeId = $0 }
        )
    }

    func createBill() -> Bill? {
        let safeAmount = amount.replacingOccurrences(of: ",", with: ".")
        guard let doubleAmount = Double(safeAmount) else {
            return nil
        }

        var bill = currentBill
        bill.amount = doubleAmount
        bill.what = topic
        bill.date = billDate
        bill.payer_id = selectedPayer
        bill.owers = povm.actualOwers()
        bill.repeat = currentProject.backend == .cospend ? currentBill.repeat : nil
        bill.categoryid = selectedCategoryId
        bill.paymentmodeid = selectedPaymentModeId
        bill.lastchanged = 0
        return bill
    }

    func prefillData() {
        topic = currentBill.what
        if currentBill.amount != 0 {
            amount = String(currentBill.amount)
        }

        selectedPayer = currentBill.payer_id ==  -1 ? currentProject.me ?? 0 : currentBill.payer_id
        currentBill.owers.forEach { person in
            if let index = povm.members.firstIndex(of: person) {
                povm.isOwing[index] = true
            }
        }
        billDate = currentBill.date
        selectedCategoryId = currentProject.categoryId(of: currentBill) ?? 0
        selectedPaymentModeId = currentBill.paymentmodeid ?? 0
    }
}
