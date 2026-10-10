//
//  AddServerModel.swift
//  PayForMe
//
//  Created by Camille Mainz on 05.02.20.
//

import Combine
import Foundation
import SlickLoadingSpinner
import UIKit

struct InviteData {
    let baseUrl: String
    let token: String
    let project: String
}

class AddProjectManualViewModel: ObservableObject {
    @Published
    var projectType = ProjectBackend.cospend

    @Published
    var serverAddress = ""

    @Published
    var projectName = ""

    @Published
    var projectPassword = ""

    @Published var inviteUrl = ""

    @Published var validationProgress = LoadingState.notStarted

    @Published var errorText = ""

    private var lastProjectTestedSuccessfully: Project?

    private var cancellables = Set<AnyCancellable>()

    /// Saved input state per backend, so fields persist when switching between Cospend and iHateMoney without mixing.
    private struct TabState {
        var serverAddress = ""
        var projectName = ""
        var projectPassword = ""
        var inviteUrl = ""
        var validationProgress = LoadingState.notStarted
        var errorText = ""
        var lastProjectTestedSuccessfully: Project?
    }

    private var tabStates: [ProjectBackend: TabState] = [:]
    private var currentTab: ProjectBackend = .cospend

    init() {
        validatedInput.map { _ in LoadingState.connecting }.assign(to: &$validationProgress)
        validatedServer.map { $0 == 200 ? LoadingState.success : LoadingState.failure }.assign(to: &$validationProgress)
        errorTextPublisher.assign(to: &$errorText)
        serverCheckUnsupportedProtocoll.assign(to: &$errorText)

        $inviteUrl
            .filter { _ in self.projectType == .iHateMoney }
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] token in self?.validateInviteToken(token) }
            .store(in: &cancellables)

        // On backend switch, save the old tab's state and restore the new one, keeping Cospend and
        // iHateMoney inputs separate. Runs synchronously when projectType is set; since `pasteAddress`
        // sets projectType before the fields, a pasted link correctly overwrites the restored values.
        $projectType
            .dropFirst()
            .sink { [weak self] newTab in
                guard let self, newTab != self.currentTab else { return }
                self.tabStates[self.currentTab] = TabState(
                    serverAddress: self.serverAddress,
                    projectName: self.projectName,
                    projectPassword: self.projectPassword,
                    inviteUrl: self.inviteUrl,
                    validationProgress: self.validationProgress,
                    errorText: self.errorText,
                    lastProjectTestedSuccessfully: self.lastProjectTestedSuccessfully
                )
                let restored = self.tabStates[newTab] ?? TabState()
                self.currentTab = newTab
                self.serverAddress = restored.serverAddress
                self.projectName = restored.projectName
                self.projectPassword = restored.projectPassword
                self.inviteUrl = restored.inviteUrl
                self.lastProjectTestedSuccessfully = restored.lastProjectTestedSuccessfully
                // Set status last so the synchronous reset/error publishers above (reacting to field changes) don't overwrite it.
                self.validationProgress = restored.validationProgress
                self.errorText = restored.errorText
            }
            .store(in: &cancellables)

        // When input becomes incomplete (e.g. pasted link cleared or tab switched), reset the
        // connection spinner immediately instead of spinning forever.
        Publishers.CombineLatest4($projectType, $serverAddress, $projectName, $projectPassword)
            .combineLatest($inviteUrl)
            .sink { [weak self] combo, invite in
                guard let self else { return }
                let (type, server, name, _) = combo
                let hasCompleteInput: Bool
                switch type {
                case .cospend:
                    // Mirror validatedInput: Cospend accepts an empty password (sent as "no-pass"),
                    hasCompleteInput = !server.isEmpty && !name.isEmpty
                case .iHateMoney:
                    hasCompleteInput = !invite.isEmpty
                }
                if !hasCompleteInput {
                    self.validationProgress = .notStarted
                    self.errorText = ""
                }
            }
            .store(in: &cancellables)
    }



    func reset() {
        serverAddress = ""
        projectName = ""
        projectPassword = ""
    }

    func addProject() {
        guard let project = lastProjectTestedSuccessfully else { return }
        do {
            try ProjectManager.shared.addProject(project)
        } catch {
            errorText = "Could not save project"
        }
    }

    private func validateInviteToken(_ input: String) {
        guard let inviteData = inviteData(from: input) else {
            // Incomplete/empty input: don't get stuck in the connection spinner.
            validationProgress = .notStarted
            return
        }
        validationProgress = .connecting
        Task { @MainActor in
            do {
                let testedProject = try await NetworkService.shared.getProjectName(invite: inviteData)
                self.lastProjectTestedSuccessfully = testedProject
                self.validationProgress = .success
            } catch {
                print("Invite URL failed: \(error)")
                self.validationProgress = .failure
            }
        }
    }

    /// Builds `InviteData` from the field contents. Accepts a full invite URL of the form
    /// `https://host/<project>/join/<token>` (server and project are derived and filled into the
    /// fields) or, as a fallback, a raw token with separately filled server and project.
    private func inviteData(from input: String) -> InviteData? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed),
           let scheme = url.scheme, let host = url.host,
           let joinIndex = url.pathComponents.firstIndex(of: "join"),
           joinIndex >= 2, joinIndex + 1 < url.pathComponents.count {
            // Locate project/token relative to the "join" segment so a reverse-proxied
            // subpath doesn't shift the indices. Keep the port and any prefix path so the
            // derived base URL stays reachable.
            let project = url.pathComponents[joinIndex - 1]
            let token = url.pathComponents[joinIndex + 1]
            var baseUrl = "\(scheme)://\(host)"
            if let port = url.port {
                baseUrl += ":\(port)"
            }
            let prefix = url.pathComponents[1 ..< (joinIndex - 1)]
            if !prefix.isEmpty {
                baseUrl += "/" + prefix.joined(separator: "/")
            }
            serverAddress = baseUrl
            projectName = project
            return InviteData(baseUrl: baseUrl, token: token, project: project)
        }

        guard !serverAddress.isEmpty, !projectName.isEmpty else { return nil }
        let baseUrl = serverAddress.hasPrefix("https://") ? serverAddress : "https://\(serverAddress)"
        return InviteData(baseUrl: baseUrl, token: trimmed, project: projectName)
    }

    /// Checks whether clipboard text is a project link that fits the form; same detection as
    /// `pasteAddress` but without mutating the fields.
    func canPaste(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else { return false }
        switch url.decodeQRCode() {
        case is ProjectDataWithPassword, is ProjectDataWithToken:
            return true
        default:
            return url.pathComponents.contains("join")
                && url.scheme != nil && url.host != nil
                && url.pathComponents.count >= 4
        }
    }

    func pasteAddress(address: String) {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedAddress) else { return }

        switch url.decodeQRCode() {
        case let project as ProjectDataWithPassword:
            projectType = .cospend
            serverAddress = project.server.absoluteString
            projectName = project.project
            projectPassword = project.password ?? ""
        case let project as ProjectDataWithToken:
            projectType = .iHateMoney
            serverAddress = project.server.absoluteString
            projectName = project.project
            inviteUrl = project.token
        default:
            guard let scheme = url.scheme, let host = url.host,
                  let joinIndex = url.pathComponents.firstIndex(of: "join"),
                  joinIndex >= 2, joinIndex + 1 < url.pathComponents.count else { return }
            // Same relative parsing as inviteData(from:): tolerate a reverse-proxied subpath
            // and preserve the port so the base URL stays reachable.
            projectType = .iHateMoney
            var baseUrl = "\(scheme)://\(host)"
            if let port = url.port {
                baseUrl += ":\(port)"
            }
            let prefix = url.pathComponents[1 ..< (joinIndex - 1)]
            if !prefix.isEmpty {
                baseUrl += "/" + prefix.joined(separator: "/")
            }
            serverAddress = baseUrl
            projectName = url.pathComponents[joinIndex - 1]
            inviteUrl = url.pathComponents[joinIndex + 1]
        }
    }

    var serverAddressFormatted: AnyPublisher<String, Never> {
        $serverAddress
            .map { $0.hasPrefix("https://") ? $0 : "https://\($0)" }
            .map { unformatted in
                if let index = unformatted.index(of: "/index.php") {
                    if let url = URL(string: unformatted) {
                        self.fillFieldsFromComponents(components: url.pathComponents)
                    }
                    return String(unformatted[..<index])
                }
                return unformatted
            }.eraseToAnyPublisher()
    }

    var serverCheckUnsupportedProtocoll: AnyPublisher<String, Never> {
        serverAddressFormatted
            .map {
                $0.contains("http://") ? "PayForMe doesn't support http" : ""
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    private func fillFieldsFromComponents(components: [String]) {
        if components.count == 6 {
            projectPassword = components[5]
            projectName = components[4]
        }
        if components.count == 5 {
            projectPassword = "no-pass"
            projectName = components[4]
        }
    }

    private var validatedAddress: AnyPublisher<(type: ProjectBackend, address: String?), Never> {
        return Publishers.CombineLatest($projectType, serverAddressFormatted)
            .map {
                type, serverAddress in
                if type == .iHateMoney, serverAddress == "https://" {
                    return (type, NetworkService.iHateMoneyURLString)
                } else {
                    return (type, serverAddress)
                }
            }
            .eraseToAnyPublisher()
    }

    lazy var validatedInput: AnyPublisher<Project, Never> = {
        Publishers.CombineLatest3(validatedAddress, $projectName, $projectPassword)
            .debounce(for: 1, scheduler: DispatchQueue.main)
            .compactMap { server, token, password -> Project? in
                guard let address = server.address, address.isValidURL, !token.isEmpty,
                      let url = URL(string: address) else { return nil }
                // Cospend allows an empty password: "no-pass" is sent then. The user can enter a real password to override.
                let effectivePassword: String
                if server.0 == .cospend {
                    effectivePassword = password.isEmpty ? "no-pass" : password
                } else {
                    guard !password.isEmpty else { return nil }
                    effectivePassword = password
                }
                // iHateMoney is addressed by the project id, which it derives
                // from the name. The name is all users ever see, so accept it
                // and convert it the same way the server does.
                let identifier = server.0.projectIdentifier(fromUserInput: token)
                return Project(name: token, password: effectivePassword, token: identifier, backend: server.0, url: url, projectId: identifier)
            }
            .removeDuplicates()
            .share()
            .eraseToAnyPublisher()
    }()

    private lazy var validatedServer: AnyPublisher<Int, Never> = {
        validatedInput
            .map { project -> AnyPublisher<(Project?, Int), Never> in
                Future<(Project?, Int), Never> { promise in
                    Task {
                        do {
                            let testedProject = try await NetworkService.shared.getProjectName(project)
                            promise(.success((testedProject, 200)))
                        } catch let urlError as URLError where urlError.code == .networkConnectionLost {
                            promise(.success((nil, NetworkService.invalidServerResponseStatusCode)))
                        } catch {
                            promise(.success((nil, -1)))
                        }
                    }
                }
                .eraseToAnyPublisher()
            }
            .switchToLatest()
            .receive(on: RunLoop.main)
            .handleEvents(receiveOutput: { (project, _) in
                self.lastProjectTestedSuccessfully = project
            })
            .map { (_, statusCode) in statusCode }
            .removeDuplicates()
            .share()
            .eraseToAnyPublisher()
    }()

    private var errorTextPublisher: AnyPublisher<String, Never> {
        validatedServer
            .map {
                statusCode in
                switch statusCode {
                case 200:
                    return ""
                case NetworkService.invalidServerResponseStatusCode:
                    return "Server returned an invalid HTTP response"
                case -1:
                    return "Could not find server"
                case 401:
                    return "Unauthorized: Wrong project id/pw"
                default:
                    return "Server error: \(statusCode)"
                }
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
