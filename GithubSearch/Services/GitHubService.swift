//
//  GitHubService.swift
//  GithubSearch
//
//  Created by Ula on 17/02/2026.
//

import Foundation
import RxSwift

struct RepoPage: Equatable {
    let repos: [Repo]
    let hasNextPage: Bool
}

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
            return L10n.GitHubServiceError.invalidUsername
        case .userNotFound:
            return L10n.GitHubServiceError.userNotFound
        case .connectivity:
            return L10n.GitHubServiceError.connectivity
        case .rateLimited:
            return L10n.GitHubServiceError.rateLimited
        case .decoding, .unknown:
            return L10n.Common.genericErrorMessage
        }
    }
}

protocol GitHubServiceType {
    func fetchRepos(username: String, page: Int, perPage: Int, sort: SearchSort) -> Single<RepoPage>
}

final class GitHubService: GitHubServiceType {

    private let client: NetworkClientType
    private let decoder: JSONDecoder

    init(client: NetworkClientType = NetworkClient(),
         decoder: JSONDecoder = JSONDecoder()) {
        self.client = client
        self.decoder = decoder
    }

    func fetchRepos(username: String, page: Int, perPage: Int, sort: SearchSort = .bestMatch) -> Single<RepoPage> {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = GitHubAPI.reposURL(username: trimmed, page: page, perPage: perPage, sort: sort) else {
            return .error(GitHubServiceError.invalidURL)
        }

        return client.get(url: url)
            .flatMap { [decoder] http, data in
                guard (200..<300).contains(http.statusCode) else {
                    return .error(Self.mapHTTPStatus(http.statusCode))
                }
                do {
                    let repos = try decoder.decode([Repo].self, from: data)
                    let page = RepoPage(
                        repos: Self.sort(repos, by: sort),
                        hasNextPage: Self.hasNextPage(http)
                    )
                    return .just(page)
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

    private static func hasNextPage(_ response: HTTPURLResponse) -> Bool {
        guard let linkHeader = response.value(forHTTPHeaderField: "Link") else {
            return false
        }

        return linkHeader.contains("rel=\"next\"")
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

    private static func sort(_ repos: [Repo], by sort: SearchSort) -> [Repo] {
        switch sort {
        case .stars:
            return repos.sorted { lhs, rhs in
                lhs.stargazersCount > rhs.stargazersCount
            }
        case .bestMatch, .updated, .name:
            return repos
        }
    }
}
