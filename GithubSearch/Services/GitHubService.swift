//
//  GitHubService.swift
//  GithubSearch
//
//  Created by Ula on 17/02/2026.
//

import Foundation
import RxSwift

enum GitHubServiceError: Error, Equatable {
    case invalidURL
    case userNotFound
    case connectivity
    case rateLimited
    case decoding
    case unknown

    var userMessage: String {
        switch self {
        case .invalidURL:
            return "Enter a valid GitHub username."
        case .userNotFound:
            return "We couldn't find that GitHub user."
        case .connectivity:
            return "You're offline right now. Check your internet connection and try again."
        case .rateLimited:
            return "GitHub is receiving too many requests right now. Please wait a moment and try again."
        case .decoding, .unknown:
            return "Something went wrong. Please try again."
        }
    }
}

protocol GitHubServiceType {
    func fetchRepos(username: String) -> Single<[Repo]>
}

final class GitHubService: GitHubServiceType {

    private let client: NetworkClientType
    private let decoder: JSONDecoder

    init(client: NetworkClientType = NetworkClient(),
         decoder: JSONDecoder = JSONDecoder()) {
        self.client = client
        self.decoder = decoder
    }

    func fetchRepos(username: String) -> Single<[Repo]> {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = GitHubAPI.reposURL(username: trimmed) else {
            return .error(GitHubServiceError.invalidURL)
        }

        return client.get(url: url)
            .flatMap { [decoder] http, data in
                guard (200..<300).contains(http.statusCode) else {
                    return .error(Self.mapHTTPStatus(http.statusCode))
                }
                do {
                    let repos = try decoder.decode([Repo].self, from: data)
                    return .just(repos)
                } catch {
                    return .error(GitHubServiceError.decoding)
                }
            }
            .catch { error in
                if let serviceError = error as? GitHubServiceError {
                    return .error(serviceError)
                }
                if let urlError = error as? URLError,
                   Self.isConnectivityError(urlError) {
                    return .error(GitHubServiceError.connectivity)
                }
                return .error(GitHubServiceError.unknown)
            }
    }

    private static func mapHTTPStatus(_ statusCode: Int) -> GitHubServiceError {
        switch statusCode {
        case 404:
            return .userNotFound
        case 403:
            return .rateLimited
        default:
            return .unknown
        }
    }

    private static func isConnectivityError(_ error: URLError) -> Bool {
        switch error.code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .cannotConnectToHost,
             .cannotFindHost,
             .dnsLookupFailed,
             .internationalRoamingOff,
             .callIsActive,
             .dataNotAllowed,
             .timedOut:
            return true
        default:
            return false
        }
    }
}
