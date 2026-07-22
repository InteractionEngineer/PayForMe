//
//  OnboardingView.swift
//  PayForMe
//
//  Created by Max Tharr on 21.01.20.
//

import Combine
import SlickLoadingSpinner
import SwiftUI
import UIKit

struct AddProjectManualView: View {
    @Environment(\.dismiss)
    private var dismiss

    @StateObject
    private var viewmodel = AddProjectManualViewModel()

    /// True, wenn die Zwischenablage (datenschutzfreundlich, ohne Inhalt zu lesen) eine URL enthält.
    @State private var clipboardHasURL = false

    var body: some View {
        NavigationView {
            Form {
                if clipboardHasURL {
                    Section {
                        pasteButton
                    }
                }

                Section {
                    NavigationLink {
                        ProjectQRPermissionCheckerView()
                    } label: {
                        Label("Scan QR code", systemImage: "qrcode.viewfinder")
                    }
                }

                Section {
                    Picker("Backend", selection: $viewmodel.projectType) {
                        Text("Cospend").tag(ProjectBackend.cospend)
                        Text("iHateMoney").tag(ProjectBackend.iHateMoney)
                    }
                    .pickerStyle(.segmented)
                }

                Section(
                    header: Text(LocalizedStringKey(viewmodel.projectType == .iHateMoney ? "Server Address (Optional)" : "Server Address")),
                    footer: Text(LocalizedStringKey(viewmodel.projectType == .cospend ? "server_hint_cospend" : "server_hint_ihatemoney"))
                ) {
                    TextFieldContainer(
                        viewmodel.projectType == .cospend
                        ? "https://mynextcloud.org" : "https://ihatemoney.org",
                        text: self.$viewmodel.serverAddress
                    )
                }

                Section(header: Text("Project ID & Password")) {
                    TextField("Enter project id", text: self.$viewmodel.projectName)
                        .autocapitalization(.none)
                    SecureField("Enter project password", text: self.$viewmodel.projectPassword)
                }

                if viewmodel.projectType == .iHateMoney {
                    Section(header: Text("Invite Token")) {
                        TextField("Enter invite url", text: self.$viewmodel.inviteUrl)
                            .autocapitalization(.none)
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        if viewmodel.validationProgress == .connecting {
                            SlickLoadingSpinner(connectionState: viewmodel.validationProgress)
                                .frame(width: 50, height: 50)
                        } else {
                            FancyButton(add: false, action: addButton, text: "Add Project")
                                .disabled(viewmodel.validationProgress != .success)
                        }
                        Spacer()
                    }
                    if !viewmodel.errorText.isEmpty {
                        Text(viewmodel.errorText)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .id(viewmodel.projectType == .cospend ? "cospend" : "iHateMoney")
            .navigationTitle("Add project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear { detectClipboard() }
    }

    @ViewBuilder
    private var pasteButton: some View {
        if #available(iOS 16.0, *) {
            PasteButton(payloadType: String.self) { strings in
                guard let first = strings.first else { return }
                pasteLink(pasteString: first)
            }
        } else {
            Button {
                pasteLink()
            } label: {
                Label("Paste Link", systemImage: "doc.on.clipboard")
            }
        }
    }

    /// Prüft datenschutzfreundlich (ohne Inhalt zu lesen, kein Paste-Hinweis), ob die
    /// Zwischenablage eine URL enthält, und blendet nur dann den Einfügen-Button ein.
    private func detectClipboard() {
        UIPasteboard.general.detectPatterns(for: [\.probableWebURL]) { result in
            guard case let .success(patterns) = result else { return }
            DispatchQueue.main.async {
                clipboardHasURL = patterns.contains(\.probableWebURL)
            }
        }
    }

    func addButton() {
        viewmodel.addProject()
        dismiss()
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
