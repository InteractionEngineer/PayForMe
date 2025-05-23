//
//  OnboardingView.swift
//  PayForMe
//
//  Created by Max Tharr on 21.01.20.
//

import Combine
import SlickLoadingSpinner
import SwiftUI

struct AddProjectManualView: View {
    @Environment(\.presentationMode)
    var presentationMode: Binding<PresentationMode>

    @StateObject
    private var viewmodel = AddProjectManualViewModel()

    var body: some View {
        VStack {
            Text("Add project").font(.title)
            Picker(selection: $viewmodel.projectType, label: Text("snens")) {
                Text("Cospend").tag(ProjectBackend.cospend)
                Text("iHateMoney").tag(ProjectBackend.iHateMoney)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(EdgeInsets(top: 8, leading: 8, bottom: 0, trailing: 8))
            if viewmodel.projectType == .cospend {
                if #available(iOS 16.0, *) {
                    PasteButton(payloadType: String.self) { strings in
                        pasteLink(pasteString: strings[0])
                    }
                    .padding(.top, 10)
                } else {
                    Button("Paste Link") {
                        pasteLink()
                    }
                    .padding(.top, 10)
                }
            }
            Form {
                Section(
                    header: Text(viewmodel.projectType == .iHateMoney ? "Server Address (Optional)" : "Server Address")
                ) {
                    TextFieldContainer(
                        viewmodel.projectType == .cospend
                            ? "https://mynextcloud.org" : "https://ihatemoney.org",
                        text: self.$viewmodel.serverAddress
                    )
                }

                Section(header: Text("Project ID & Password")) {
                    TextField("Enter project id",
                              text: self.$viewmodel.projectName)
                        .autocapitalization(.none)

                    SecureField("Enter project password", text: self.$viewmodel.projectPassword)
                }
            }
            .id(viewmodel.projectType == .cospend ? "cospend" : "iHateMoney")
            .frame(width: UIScreen.main.bounds.width, height: 220, alignment: .center)
            SlickLoadingSpinner(connectionState: viewmodel.validationProgress)
                .frame(width: 50, height: 50)
            FancyButton(
                add: false,
                action: addButton,
                text: "Add Project"
            )
            .disabled(viewmodel.validationProgress != .success)
            if !viewmodel.errorText.isEmpty {
                Text(viewmodel.errorText)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 50)
        .background(Color.PFMBackground)
    }

    func addButton() {
        viewmodel.addProject()
        presentationMode.wrappedValue.dismiss()
    }
    
    private func pasteLink(pasteString: String) {
        viewmodel.pasteAddress(address: pasteString)
    }

    private func pasteLink() {
        if let pasteString = UIPasteboard.general.string {
            print(pasteString)
            viewmodel.pasteAddress(address: pasteString)
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        AddProjectManualView().environment(\.locale, .init(identifier: "de"))
    }
}
