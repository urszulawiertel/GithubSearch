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
    func fetchLanguages(owner: String, repo: String, forceRefresh: Bool) -> Single<[RepositoryLanguage]>
    func fetchReadme(owner: String, repo: String, forceRefresh: Bool) -> Single<RepositoryReadme?>
    func fetchLatestRelease(owner: String, repo: String) -> Single<RepositoryRelease?>
}

final class RepositoryDetailsCache {
    private var languagesByRepository: [String: [RepositoryLanguage]] = [:]
    private var readmeByRepository: [String: RepositoryReadme?] = [:]
    private let lock = NSLock()

    func languages(owner: String, repo: String) -> [RepositoryLanguage]? {
        lock.lock()
        defer { lock.unlock() }
        return languagesByRepository[key(owner: owner, repo: repo)]
    }

    func storeLanguages(_ languages: [RepositoryLanguage], owner: String, repo: String) {
        lock.lock()
        languagesByRepository[key(owner: owner, repo: repo)] = languages
        lock.unlock()
    }

    func readme(owner: String, repo: String) -> RepositoryReadme?? {
        lock.lock()
        defer { lock.unlock() }
        let key = key(owner: owner, repo: repo)
        guard readmeByRepository.keys.contains(key) else {
            return nil
        }
        return readmeByRepository[key] ?? nil
    }

    func storeReadme(_ readme: RepositoryReadme?, owner: String, repo: String) {
        lock.lock()
        readmeByRepository[key(owner: owner, repo: repo)] = readme
        lock.unlock()
    }

    private func key(owner: String, repo: String) -> String {
        "\(owner.lowercased())/\(repo.lowercased())"
    }
}

final class GitHubService: GitHubServiceType {

    private let client: NetworkClientType
    private let decoder: JSONDecoder
    private let cache: RepositoryDetailsCache

    init(client: NetworkClientType = NetworkClient(),
         decoder: JSONDecoder = JSONDecoder(),
         cache: RepositoryDetailsCache = RepositoryDetailsCache()) {
        self.client = client
        self.decoder = decoder
        self.cache = cache
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

    func fetchLanguages(owner: String, repo: String, forceRefresh: Bool = false) -> Single<[RepositoryLanguage]> {
        if !forceRefresh, let cachedLanguages = cache.languages(owner: owner, repo: repo) {
            return .just(cachedLanguages)
        }

        guard let url = GitHubAPI.languagesURL(owner: owner, repo: repo) else {
            return .error(GitHubServiceError.invalidURL)
        }

        return client.get(url: url)
            .flatMap { [decoder, cache] http, data in
                guard (200..<300).contains(http.statusCode) else {
                    if http.statusCode == 404 {
                        cache.storeLanguages([], owner: owner, repo: repo)
                        return .just([])
                    }
                    return .error(Self.mapHTTPStatus(http.statusCode))
                }

                do {
                    let languageBytes = try decoder.decode([String: Int].self, from: data)
                    let languages = Self.makeLanguages(from: languageBytes)
                    cache.storeLanguages(languages, owner: owner, repo: repo)
                    return .just(languages)
                } catch {
                    return .error(GitHubServiceError.decoding)
                }
            }
            .catch(Self.mapTransportError)
    }

    func fetchReadme(owner: String, repo: String, forceRefresh: Bool = false) -> Single<RepositoryReadme?> {
        if !forceRefresh, let cachedReadme = cache.readme(owner: owner, repo: repo) {
            return .just(cachedReadme)
        }

        guard let url = GitHubAPI.readmeURL(owner: owner, repo: repo) else {
            return .error(GitHubServiceError.invalidURL)
        }

        return client.get(url: url)
            .flatMap { [decoder, cache] http, data in
                guard (200..<300).contains(http.statusCode) else {
                    if http.statusCode == 404 {
                        cache.storeReadme(nil, owner: owner, repo: repo)
                        return .just(nil)
                    }
                    return .error(Self.mapHTTPStatus(http.statusCode))
                }

                do {
                    let response = try decoder.decode(GitHubReadmeResponse.self, from: data)
                    guard response.encoding.caseInsensitiveCompare("base64") == .orderedSame,
                          let decodedData = Data(base64Encoded: response.content, options: .ignoreUnknownCharacters),
                          let text = String(data: decodedData, encoding: .utf8) else {
                        return .error(GitHubServiceError.decoding)
                    }
                    let readme = RepositoryReadme(text: text)
                    cache.storeReadme(readme, owner: owner, repo: repo)
                    return .just(readme)
                } catch {
                    return .error(GitHubServiceError.decoding)
                }
            }
            .catch(Self.mapTransportError)
    }

    func fetchLatestRelease(owner: String, repo: String) -> Single<RepositoryRelease?> {
        guard let url = GitHubAPI.latestReleaseURL(owner: owner, repo: repo) else {
            return .error(GitHubServiceError.invalidURL)
        }

        return client.get(url: url)
            .flatMap { [decoder] http, data in
                guard (200..<300).contains(http.statusCode) else {
                    if http.statusCode == 404 {
                        return .just(nil)
                    }
                    return .error(Self.mapHTTPStatus(http.statusCode))
                }

                do {
                    let response = try decoder.decode(GitHubReleaseResponse.self, from: data)
                    return .just(RepositoryRelease(
                        name: Self.normalized(response.name) ?? response.tagName,
                        tagName: response.tagName,
                        publishedAt: response.publishedAt,
                        body: response.body
                    ))
                } catch {
                    return .error(GitHubServiceError.decoding)
                }
            }
            .catch(Self.mapTransportError)
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

    private static func mapTransportError<T>(_ error: Error) -> Single<T> {
        if let serviceError = error as? GitHubServiceError {
            return .error(serviceError)
        }
        if let urlError = error as? URLError,
           Self.isConnectivityError(urlError) {
            return .error(GitHubServiceError.connectivity)
        }
        return .error(GitHubServiceError.unknown)
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

    private static func makeLanguages(from languageBytes: [String: Int]) -> [RepositoryLanguage] {
        let totalBytes = languageBytes.values.reduce(0, +)
        guard totalBytes > 0 else {
            return []
        }

        return languageBytes
            .map { name, bytes in
                RepositoryLanguage(
                    name: name,
                    bytes: bytes,
                    percentage: (Double(bytes) / Double(totalBytes)) * 100
                )
            }
            .sorted { lhs, rhs in
                if lhs.bytes == rhs.bytes {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.bytes > rhs.bytes
            }
    }

    private static func normalized(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
