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
    var lastPage: Int?
    var lastPerPage: Int?
    var lastSort: SearchSort?
    var requestedPages: [Int] = []
    var requestedSorts: [SearchSort] = []

    var stubbedPage = RepoPage(repos: [], hasNextPage: false)
    var stubbedError: Error?
    var fetchReposHandler: ((String, Int, Int, SearchSort) -> Single<RepoPage>)?

    func fetchRepos(username: String, page: Int, perPage: Int, sort: SearchSort) -> Single<RepoPage> {
        fetchReposCallCount += 1
        lastUsername = username
        lastPage = page
        lastPerPage = perPage
        lastSort = sort
        requestedPages.append(page)
        requestedSorts.append(sort)

        if let fetchReposHandler {
            return fetchReposHandler(username, page, perPage, sort)
        }

        if let stubbedError {
            return .error(stubbedError)
        }
        return .just(stubbedPage)
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
