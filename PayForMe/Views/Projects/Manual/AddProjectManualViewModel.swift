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
    let url: String
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
            errorText = "Project already exists!"
        }
    }

    private func validateInviteToken(_ token: String) {
        guard !token.isEmpty, !serverAddress.isEmpty, !projectName.isEmpty else { return }
        let baseUrl = serverAddress.hasPrefix("https://") ? serverAddress : "https://\(serverAddress)"
        let inviteData = InviteData(url: baseUrl, baseUrl: baseUrl, token: token, project: projectName)
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

    func pasteAddress(address: String) {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedAddress) else { return }

        switch url.decodeQRCode() {
        case let project as ProjectDataWithPassword:
            serverAddress = project.server.absoluteString
            projectName = project.project
            projectPassword = project.password ?? ""
        case let project as ProjectDataWithToken:
            projectType = .iHateMoney
            serverAddress = project.server.absoluteString
            projectName = project.project
            inviteUrl = project.token
        default:
            guard url.pathComponents.contains("join"),
                  let scheme = url.scheme, let host = url.host,
                  url.pathComponents.count >= 4 else { return }
            projectType = .iHateMoney
            serverAddress = "\(scheme)://\(host)"
            projectName = url.pathComponents[1]
            inviteUrl = url.pathComponents[3]
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
                if let address = server.address, address.isValidURL, !token.isEmpty, !password.isEmpty {
                    guard let url = URL(string: address) else { return nil }
                    return Project(name: token, password: password, token: token, backend: server.0, url: url, projectId: self.projectName)
                } else {
                    return nil
                }
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
