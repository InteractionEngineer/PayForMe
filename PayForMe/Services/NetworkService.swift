//
//  CospendNetworkservice.swift
//  PayForMe
//
//  Created by Max Tharr on 21.01.20.
//

import Combine
import Foundation

/// Why loading a project's data failed.
///
/// The load publishers used to declare `Never` as their failure type, which
/// left everything upstream unable to tell "this project is empty" from "the
/// server rejected us". Changing a project's password on the server therefore
/// showed empty lists and no explanation at all (#37).
enum LoadError: Error, Equatable, Identifiable {
    /// Credentials rejected. Usually the project password was changed on the
    /// server after it was added here.
    case unauthorized
    case notFound
    case http(Int)
    /// No usable connection, or a response that was not HTTP at all.
    case connection
    /// The server answered, but not with something we could decode.
    case invalidResponse

    var id: String { String(describing: self) }

    init(statusCode: Int) {
        switch statusCode {
        case 401, 403:
            self = .unauthorized
        case 404:
            self = .notFound
        default:
            self = .http(statusCode)
        }
    }

    init(_ error: Error) {
        switch error {
        case let serverError as LoadError:
            self = serverError
        case is URLError:
            self = .connection
        default:
            // Decoding failed: the server answered, we just could not read it.
            self = .invalidResponse
        }
    }
}

class NetworkService {
    static let shared = NetworkService()

    /// `URLError.networkConnectionLost` (-1005) surfaced as a status code so the UI
    /// can distinguish it from a generic failure. Usually caused by a server
    /// returning an HTTP/2-illegal header such as `Upgrade` (RFC 7540 §8.1.2.2).
    static let invalidServerResponseStatusCode = -1005

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

    /// Turns a response into its body or into a typed failure. Both cases used
    /// to collapse into "no value emitted", which is precisely what made a
    /// rejected password indistinguishable from an empty project.
    private static func validate(_ data: Data, _ response: URLResponse) throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LoadError.connection
        }
        guard httpResponse.statusCode == 200 else {
            throw LoadError(statusCode: httpResponse.statusCode)
        }
        return data
    }

    func loadBillsPublisher(_ project: Project) -> AnyPublisher<[Bill], LoadError> {
        let request = buildURLRequest("bills", params: [:], project: project)
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in try NetworkService.validate(data, response) }
            .decode(type: [Bill].self, decoder: decoder)
            .mapError { LoadError($0) }
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

    func loadMembersPublisher(_ project: Project) -> AnyPublisher<[Int: Person], LoadError> {
        let request = buildURLRequest("members", params: [:], project: project)
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in try NetworkService.validate(data, response) }
            .decode(type: [Person].self, decoder: decoder)
            .mapError { LoadError($0) }
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
            .map { _, response -> Int in
                (response as? HTTPURLResponse)?.statusCode ?? -1
            }
            .catch { (urlError: URLError) -> Just<Int> in
                Just(urlError.code == .networkConnectionLost
                     ? NetworkService.invalidServerResponseStatusCode
                     : -1)
            }
        return Publishers.CombineLatest(Just(project), requestPub).eraseToAnyPublisher()
    }

    func getProjectName(_ project: Project) async throws -> Project {
        let request = buildURLRequest("", params: [:], project: project)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode / 100 == 2 else {
            throw HTTPError.statuscode
        }
        let apiProject = try JSONDecoder().decode(APIProject.self, from: data)

        return Project(name: apiProject.name, password: project.password, token: project.token, backend: project.backend, url: project.url, projectId: apiProject.id)
    }

    func getProjectName(invite: InviteData) async throws -> Project {
        guard var components = URLComponents(string: invite.baseUrl),
              let baseURL = components.url else {
            throw URLError(.badURL)
        }
        components.path += iHateMoneyStaticPath + "/" + invite.project
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(
            "Bearer \(invite.token)",
            forHTTPHeaderField: "Authorization"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode / 100 == 2 else {
            throw HTTPError.statuscode
        }
        let apiProject = try JSONDecoder().decode(APIProject.self, from: data)

        return Project(name: apiProject.name, password: "", token: invite.token, backend: ProjectBackend.iHateMoney, url: baseURL, projectId: apiProject.id)
    }

    func postBillPublisher(bill: Bill) -> AnyPublisher<Bool, Never> {
        let request = buildURLRequest("bills", params: bill.paramsFor(currentProject.backend), project: currentProject, httpMethod: "POST")
        return sendBillPublisher(request: request)
    }

    func updateBillPublisher(bill: Bill) -> AnyPublisher<Bool, Never> {
        let request = buildURLRequest("bills/\(bill.id)", params: bill.paramsFor(currentProject.backend), project: currentProject, httpMethod: "PUT")
        return sendBillPublisher(request: request)
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

    /// Like `createMemberPublisher`, but returns the HTTP status code (-1 on transport error) so the
    /// UI can surface a real error instead of a silent `false`.
    func createMemberStatusPublisher(name: String) -> AnyPublisher<Int, Never> {
        let request = buildURLRequest("members", params: ["name": name], project: currentProject, httpMethod: "POST")
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { output -> Int in (output.response as? HTTPURLResponse)?.statusCode ?? -1 }
            .replaceError(with: -1)
            .eraseToAnyPublisher()
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

        if project.backend == .cospend {
            url = url
                .appendingPathComponent(project.token)
                .appendingPathComponent(project.password)
        }

        if project.backend == .iHateMoney {
            url = url
                .appendingPathComponent(project.projectId)
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
            if project.password.isEmpty {
                request.setValue("Bearer \(project.token)", forHTTPHeaderField: "Authorization")
            } else {
                guard let authString = "\(project.token):\(project.password)".data(using: .utf8)?.base64EncodedString() else {
                    fatalError("error generating authString. THIS SHOULD NOT HAPPEN")
                }
                request.setValue("Basic \(authString)", forHTTPHeaderField: "Authorization")
            }

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
        case statuscode
    }

    enum ServerError: LocalizedError {
        case noIdReturned
    }
}
