//
//  GitHubServiceMock.swift
//  GithubSearchTests
//
//  Created by Ula on 24/02/2026.
//

import Foundation
import RxSwift
@testable import GithubSearch

final class GitHubServiceMock: GitHubServiceType {

    var fetchReposCallCount = 0
    var lastUsername: String?

    var stubbedRepos: [Repo] = []
    var stubbedError: Error?

    func fetchRepos(username: String) -> Single<[Repo]> {
        fetchReposCallCount += 1
        lastUsername = username

        if let stubbedError {
            return .error(stubbedError)
        }
        return .just(stubbedRepos)
    }
}

extension Repo {
    static func mock(
        id: Int = 1,
        name: String = "Repo",
        fullName: String = "owner/Repo",
        description: String? = nil,
        stargazersCount: Int = 0,
        language: String? = "Swift",
        htmlUrl: URL = URL(string: "https://github.com/owner/Repo")!,
        owner: RepoOwner? = RepoOwner(login: "owner", avatarUrl: URL(string: "https://avatars.githubusercontent.com/u/1?v=4"))
    ) -> Repo {
        Repo(
            id: id,
            name: name,
            fullName: fullName,
            description: description,
            stargazersCount: stargazersCount,
            language: language,
            htmlUrl: htmlUrl,
            owner: owner
        )
    }
}
