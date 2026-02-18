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
    case http(Int)
    case decoding
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
                    return .error(GitHubServiceError.http(http.statusCode))
                }
                do {
                    let repos = try decoder.decode([Repo].self, from: data)
                    return .just(repos)
                } catch {
                    return .error(GitHubServiceError.decoding)
                }
            }
    }
}
