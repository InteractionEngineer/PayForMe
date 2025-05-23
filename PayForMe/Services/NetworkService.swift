//
//  CospendNetworkservice.swift
//  PayForMe
//
//  Created by Max Tharr on 21.01.20.
//

import Combine
import Foundation

class NetworkService {
    static let shared = NetworkService()

    private let decoder: JSONDecoder

    private init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.cospend)
    }

    private let cospendStaticPath = "/index.php/apps/cospend/api/projects"
    private let iHateMoneyStaticPath = "/api/projects"

    static let iHateMoneyURLString = "https://ihatemoney.org"

    private var currentProject: Project {
        return ProjectManager.shared.currentProject
    }

    let networkActivityPublisher = PassthroughSubject<Bool, Never>()

    func loadBillsPublisher(_ project: Project) -> AnyPublisher<[Bill], Never> {
        let request = buildURLRequest("bills", params: [:], project: project)
        return URLSession.shared.dataTaskPublisher(for: request)
            .compactMap { data, response -> Data? in
                guard let httpResponse = response as? HTTPURLResponse else { print("Network Error"); return nil }
                guard httpResponse.statusCode == 200 else { print("Network Error: Status code: \(httpResponse.statusCode) \(httpResponse.description)"); return nil }
                return data
            }
            .decode(type: [Bill].self, decoder: decoder)
            .replaceError(with: [])
            .map {
                $0.sorted {
                    if let l1 = $0.lastchanged,
                       let l2 = $1.lastchanged
                    {
                        return l1 > l2
                    }
                    return $0.date > $1.date
                }
            }
            .eraseToAnyPublisher()
    }

    func loadMembersPublisher(_ project: Project) -> AnyPublisher<[Int: Person], Never> {
        let request = buildURLRequest("members", params: [:], project: project)
        return URLSession.shared.dataTaskPublisher(for: request)
            .compactMap { data, response -> Data? in
                guard let httpResponse = response as? HTTPURLResponse else { print("Network Error"); return nil }
                guard httpResponse.statusCode == 200 else { print("Network Error: Status code: \(httpResponse.statusCode) \(httpResponse.description)"); return nil }
                return data
            }
            .decode(type: [Person].self, decoder: decoder)
            .replaceError(with: [])
            .map {
                members in
                let filtered = members.filter {
                    $0.activated
                }
                return Dictionary(filtered.map { ($0.id, $0) }) { a, _ in a }
            }
            .eraseToAnyPublisher()
    }

    func testProject(_ project: Project) -> AnyPublisher<(Project, Int), Never> {
        let request = buildURLRequest("dummy", params: [:], project: project)
        let requestPub = URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { _, response -> Int in
                guard let httpResponse = response as? HTTPURLResponse else { print("Network Error"); return -1 }
                return httpResponse.statusCode
            }
            .replaceError(with: -1)
        return Publishers.CombineLatest(Just(project), requestPub).eraseToAnyPublisher()
    }

    func getProjectName(_ project: Project) async throws -> Project {
        let request = buildURLRequest("", params: [:], project: project)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode / 100 == 2 else {
            throw HTTPError.generalFailure
        }
        let apiProject = try JSONDecoder().decode(APIProject.self, from: data)

        return Project(name: apiProject.name, password: project.password, token: project.token, backend: project.backend, url: project.url)
    }

    func post(bill: Bill) async throws {
        let request = buildURLRequest("bills", params: bill.paramsFor(currentProject.backend), project: currentProject, httpMethod: "POST")
        try await sendWithOutResponseData(request: request)
    }

    func update(bill: Bill) async throws {
        let request = buildURLRequest("bills/\(bill.id)", params: bill.paramsFor(currentProject.backend), project: currentProject, httpMethod: "PUT")
        try await sendWithOutResponseData(request: request)
    }

    private func sendWithOutResponseData(request: URLRequest) async throws {
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw HTTPError.generalFailure
              }
        if response.statusCode / 100 == 2 {
            throw HTTPError.statuscode(code: response.statusCode)
        }
    }

    func deleteBillPublisher(bill: Bill) -> AnyPublisher<Bool, Never> {
        let request = buildURLRequest("bills/\(bill.id)", params: [:], project: currentProject, httpMethod: "DELETE")
        return sendBillPublisher(request: request)
    }

    private func sendBillPublisher(request: URLRequest) -> AnyPublisher<Bool, Never> {
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse, response.statusCode / 100 == 2 else {
                    return false
                }
                return true
            }
            .replaceError(with: false)
            .eraseToAnyPublisher()
    }

    func createMemberPublisher(name: String) -> AnyPublisher<Bool, Never> {
        let request = buildURLRequest("members", params: ["name": name], project: currentProject, httpMethod: "POST")
        return sendMemberPublisher(request: request)
    }

    func updateMemberPublisher(member: Person) -> AnyPublisher<Bool, Never> {
        let request = buildURLRequest("members/\(member.id)", params: ["name": member.name], project: currentProject, httpMethod: "PUT")
        return sendMemberPublisher(request: request)
    }

    func deleteMemberPublisher(member: Person) -> AnyPublisher<Bool, Never> {
        let request = buildURLRequest("members/\(member.id)", params: [:], project: currentProject, httpMethod: "DELETE")
        return sendMemberPublisher(request: request)
    }

    private func sendMemberPublisher(request: URLRequest) -> AnyPublisher<Bool, Never> {
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { output in
                guard let response = output.response as? HTTPURLResponse, response.statusCode / 100 == 2 else {
                    return false
                }
                return true
            }
            .replaceError(with: false)
            .eraseToAnyPublisher()
    }

    private func baseURLFor(_ project: Project, suffix: String) -> URL {
        var url = project.url
            .appendingPathComponent(project.backend.staticPath)
            .appendingPathComponent(project.token)
        if project.backend == .cospend {
            url = url.appendingPathComponent(project.password)
        }
        if suffix.isEmpty {
            return url
        } else {
            return url.appendingPathComponent(suffix)
        }
    }

    private func buildURLRequest(_ suffix: String, params: [String: Any] = [:], project: Project = ProjectManager.shared.currentProject, httpMethod: String = "GET") -> URLRequest {
        let baseURL: URL
        let requestURL: URL
        var request: URLRequest

        baseURL = baseURLFor(project, suffix: suffix)

        if let cospendParams = params as? [String: String], project.backend == .cospend, !params.isEmpty {
            var urlComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
            urlComponents?.queryItems = cospendParams.map { URLQueryItem(name: $0, value: $1) }

            requestURL = urlComponents!.url!
        } else {
            requestURL = baseURL
        }

        request = URLRequest(url: requestURL)

        if project.backend == .iHateMoney {
            guard let authString = "\(project.token):\(project.password)".data(using: .utf8)?.base64EncodedString() else { fatalError("error generating authString. THIS SHOULD NOT HAPPEN") }
            request.setValue("Basic \(authString)", forHTTPHeaderField: "Authorization")

            if !params.isEmpty {
                request.httpBody = try? JSONSerialization.data(withJSONObject: params)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
            }
        }

        request.httpMethod = httpMethod

        return request
    }

    enum HTTPError: LocalizedError {
        case statuscode(code: Int)
        case generalFailure
    }

    enum ServerError: LocalizedError {
        case noIdReturned
    }
}
