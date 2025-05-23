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

class AddProjectManualViewModel: ObservableObject {
    @Published
    var projectType = ProjectBackend.cospend

    @Published
    var serverAddress = ""

    @Published
    var projectName = ""

    @Published
    var projectPassword = ""

    @Published var validationProgress = LoadingState.notStarted

    @Published var errorText = ""

    private var lastProjectTestedSuccessfully: Project?

    init() {
        validatedInput.map { _ in LoadingState.connecting }.assign(to: &$validationProgress)
        validatedServer.map { $0 == 200 ? LoadingState.success : LoadingState.failure }.assign(to: &$validationProgress)
        errorTextPublisher.assign(to: &$errorText)
        serverCheckUnsupportedProtocoll.assign(to: &$errorText)
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

    func pasteAddress(address: String) {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedAddress) else {
            return
        }

        // If it is a moneybuster URL
        let result = url.decodeQRCode()
        
        switch result {
        case .success(let projectData):
            if let url = projectData.server, let name = projectData.project {
                serverAddress = url.absoluteString
                projectName = name
                if let password = projectData.passwd {
                    projectPassword = password
                }
                return
            }
        case .failure(let error):
            print("Failed to decode URL: \(error.localizedDescription)")
            // Optional: Handle the error, e.g., show an alert
        }
        
        // If it is another url or decoding failed
        let pathComponents = url.pathComponents
        let pureUrl = url.deletingPathExtension().absoluteString
        let trimmIndices = url.absoluteString.indices(of: "/")
        if let cutIndex = trimmIndices[safe: 2] {
            let trimmedUrl = pureUrl[...cutIndex]
            serverAddress = String(trimmedUrl)
        } else {
            serverAddress = pureUrl
        }
        fillFieldsFromComponents(components: pathComponents)
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

    var validatedInput: AnyPublisher<Project, Never> {
        return Publishers.CombineLatest3(validatedAddress, $projectName, $projectPassword)
            .debounce(for: 1, scheduler: DispatchQueue.main)
            .compactMap { server, token, password in
                if let address = server.address, address.isValidURL, !token.isEmpty, !password.isEmpty {
                    guard let url = URL(string: address) else { return nil }
                    return Project(name: token, password: password, token: token, backend: server.0, url: url)
                } else {
                    return nil
                }
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    private var validatedServer: AnyPublisher<Int, Never> {
        validatedInput.flatMap {
            project in
            Future { promise in
                Task {
                    do {
                        let testedProject = try await NetworkService.shared.getProjectName(project)
                        self.lastProjectTestedSuccessfully = testedProject
                        promise(.success(200))
                    } catch {
                        promise(.success(-1))
                    }
                }
            }
        }
        .removeDuplicates()
        .receive(on: RunLoop.main)
        .eraseToAnyPublisher()
    }

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
