//
//  AddProjectQRViewModel.swift
//  PayForMe
//
//  Created by Max Tharr on 02.10.20.
//

import Combine
import Foundation
import GRDB
import SlickLoadingSpinner
import SwiftUI

class AddProjectQRViewModel: ObservableObject {
    @Published var scannedCode: URL?
    @Published var text = ""
    @Published var askForPassword = false
    @Published var passwordText = ""

    @Published var url: URL?
    @Published var name = ""

    typealias ProjectConnectState = LoadingState
    @Published var isProject = ProjectConnectState.notStarted

    private var subscriptions = Set<AnyCancellable>()

    init() {
        foundCodeSink.store(in: &subscriptions)
        passwordCorrect.assign(to: &$isProject)
        isTestingSubject.assign(to: &$isProject)
    }

    convenience init(openedByURL: URL?) {
        self.init()
        scannedCode = openedByURL
    }

    var isTestingSubject = PassthroughSubject<ProjectConnectState, Never>()

    var passwordCorrect: AnyPublisher<ProjectConnectState, Never> {
        Publishers.CombineLatest3(
            $url
                .compactMap { $0 },
            $name,
            $passwordText
                .debounce(for: 0.5, scheduler: RunLoop.main)
                .compactMap { $0.isEmpty ? nil : $0 }
                .removeDuplicates()
        )
        .map { url, token, password in
            self.isTestingSubject.send(.connecting)
            print("\(url) \(token) \(password)")
            return Project(name: "", password: password, token: token, backend: .cospend, url: url)
        }
        .flatMap { project in
            NetworkService.shared.testProject(project)
        }
        .tryMap { project, statusCode in
            if statusCode == 200 {
                do {
                    try ProjectManager.shared.addProject(project)
                    return withAnimation {
                        .success
                    }
                } catch {
                    print(error)
                    return withAnimation {
                        .failure
                    }
                }
            }
            print("Authentication failed, your provided password might be incorrect.")
            return withAnimation {
                .failure
            }
        }
        .replaceError(with: withAnimation { .failure })
        .eraseToAnyPublisher()
    }

    var urlString: String {
        url?.absoluteString ?? "The link provided by this QR code (\(scannedCode ?? URL(string: "unreadble")!)) is invalid."
    }

    var foundCode: AnyPublisher<URL, Never> {
        $scannedCode
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }

    var foundCodeSink: AnyCancellable {
        foundCode
            .sink { codedUrl in
                let result = codedUrl.decodeQRCode()
                
                switch result {
                case .success(let projectData):
                    guard let url = projectData.server, let token = projectData.project else {
                        self.isTestingSubject.send(.failure)
                        // TODO: add error message "Missing server URL or project ID"
                        return
                    }
                    
                    if let password = projectData.passwd {
                        self.isTestingSubject.send(.connecting)
                        let project = Project(name: token, password: password, token: token, backend: .cospend, url: url)
                        Task(priority: .userInitiated) {
                            do {
                                let apiProject = try await NetworkService.shared.getProjectName(project)
                                try ProjectManager.shared.addProject(apiProject)
                                self.isTestingSubject.send(.success)
                            } catch {
                                print(codedUrl)
                                print()
                                print(error)
                                self.isTestingSubject.send(.failure)
                                // TODO: add error message "Failed to connect: \(error.localizedDescription)"
                            }
                        }
                    } else {
                        withAnimation {
                            self.url = url
                            self.name = token
                            self.askForPassword.toggle()
                        }
                    }
                    
                case .failure(let error):
                    print(codedUrl)
                    print()
                    print(error)
                    self.isTestingSubject.send(.failure)
                    
                    if let decodingError = error as? URLDecodingError {
                        // TODO: Add error message that relates to the url decoding error
                    } else {
                        // TODO: Add generic error message for any other cases
                    }
                }
            }
    }
}
