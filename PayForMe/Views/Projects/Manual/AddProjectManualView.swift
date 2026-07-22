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

    @State private var clipboardHasURL = false

    @State private var showQRScanner = false

    var body: some View {
        NavigationView {
            Form {
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
                    SecureField("Enter project password (Optional)", text: self.$viewmodel.projectPassword)
                }

                if viewmodel.projectType == .iHateMoney {
                    Section(
                        header: Text("Invite Link"),
                        footer: Text("invite_link_hint")
                    ) {
                        TextField("Enter invite link", text: self.$viewmodel.inviteUrl)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                }

                Section {
                    if viewmodel.validationProgress == .connecting {
                        HStack {
                            Spacer()
                            SlickLoadingSpinner(connectionState: viewmodel.validationProgress)
                                .frame(width: 50, height: 50)
                            Spacer()
                        }
                    } else {
                        Button(action: addButton) {
                            Text("Add Project")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .prominentActionStyle(active: viewmodel.validationProgress == .success)
                        .disabled(viewmodel.validationProgress != .success)
                    }
                    if !viewmodel.errorText.isEmpty {
                        Text(viewmodel.errorText)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .listRowBackground(Color.clear)
            }
            .id(viewmodel.projectType == .cospend ? "cospend" : "iHateMoney")
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 20) {
                    Picker("Backend", selection: $viewmodel.projectType) {
                        Text("Cospend").tag(ProjectBackend.cospend)
                        Text("iHateMoney").tag(ProjectBackend.iHateMoney)
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.large)

                    HStack(spacing: 12) {
                        qrButton
                        pasteButton
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
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
        .sheet(isPresented: $showQRScanner) {
            NavigationView {
                ProjectQRPermissionCheckerView(onFinish: { dismiss() })
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showQRScanner = false }
                        }
                    }
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }

    private var qrButton: some View {
        Button {
            showQRScanner = true
        } label: {
            Text("Scan QR code")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .prominentActionStyle()
    }

    private var pasteButton: some View {
        Button {
            handlePaste()
        } label: {
            Text("Paste Link")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .prominentActionStyle(active: clipboardHasURL)
        .disabled(!clipboardHasURL)
    }

    private func detectClipboard() {
        // iOS 16+ gates the read behind a pattern check, so contents are only inspected (and the
        // paste notification only shown) when a URL is present. That API is unavailable on iOS 15.
        if #available(iOS 16.0, *) {
            UIPasteboard.general.detectPatterns(for: [\.probableWebURL]) { result in
                guard (try? result.get())?.contains(\.probableWebURL) == true else {
                    DispatchQueue.main.async { clipboardHasURL = false }
                    return
                }
                let content = UIPasteboard.general.string ?? ""
                DispatchQueue.main.async { clipboardHasURL = viewmodel.canPaste(content) }
            }
        } else {
            clipboardHasURL = viewmodel.canPaste(UIPasteboard.general.string ?? "")
        }
    }

    func addButton() {
        viewmodel.addProject()
        dismiss()
    }

    private func handlePaste() {
        guard let pasteString = UIPasteboard.general.string else { return }
        viewmodel.pasteAddress(address: pasteString)
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        AddProjectManualView().environment(\.locale, .init(identifier: "de"))
    }
}
