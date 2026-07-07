//
//  AppLaunchEnvironment.swift
//  GithubSearch
//
//  Created by Ula on 03/04/2026.
//

import Foundation
import RxSwift

enum AppLaunchEnvironment {

    private enum Key {
        static let uiTestScenario = "UI_TEST_SCENARIO"
    }

    static func makeGitHubService() -> GitHubServiceType {
        guard let scenario = UITestScenario(rawValue: ProcessInfo.processInfo.environment[Key.uiTestScenario] ?? "") else {
            return makeDefaultGitHubService()
        }

        return makeDebuggableService(wrapping: UITestGitHubService(scenario: scenario))
    }

    private static func makeDefaultGitHubService() -> GitHubServiceType {
        makeDebuggableService(wrapping: GitHubService())
    }

    private static func makeDebuggableService(wrapping service: GitHubServiceType) -> GitHubServiceType {
        #if DEBUG
        // DEBUG-only service decoration keeps forced debug responses out of
        // SearchViewModel and compiles away entirely in Release builds.
        return DebugGitHubService(wrappedService: service)
        #else
        return service
        #endif
    }
}

private enum UITestScenario: String {
    case success
    case empty
}

private final class UITestGitHubService: GitHubServiceType {

    private let scenario: UITestScenario

    init(scenario: UITestScenario) {
        self.scenario = scenario
    }

    func fetchRepos(username: String, page: Int, perPage: Int, sort: SearchSort) -> Single<RepoPage> {
        switch scenario {
        case .success:
            return .just(RepoPage(
                repos: [
                    Repo(
                        id: 101,
                        name: "ios-github-search",
                        fullName: "\(username)/ios-github-search",
                        description: "UI test repository for the main search flow.",
                        stargazersCount: 42,
                        forksCount: 7,
                        openIssuesCount: 2,
                        watchersCount: 10,
                        language: "Swift",
                        htmlUrl: URL(string: "https://github.com/\(username)/ios-github-search")!,
                        updatedAt: GitHubDateParser.date(from: "2026-04-03T12:30:00Z"),
                        topics: ["ios", "github-api"],
                        defaultBranch: "main",
                        license: RepoLicense(name: "MIT License", spdxId: "MIT"),
                        owner: nil
                    )
                ],
                hasNextPage: false
            ))
        case .empty:
            return .just(RepoPage(repos: [], hasNextPage: false))
        }
    }

    func fetchLanguages(owner: String, repo: String, forceRefresh: Bool) -> Single<[RepositoryLanguage]> {
        .just([
            RepositoryLanguage(name: "Swift", bytes: 900, percentage: 90),
            RepositoryLanguage(name: "Ruby", bytes: 100, percentage: 10)
        ])
    }

    func fetchReadme(owner: String, repo: String, forceRefresh: Bool) -> Single<RepositoryReadme?> {
        .just(RepositoryReadme(text: """
        # iOS GitHub Search

        UI test repository detail preview.

        This fixture keeps the detail screen deterministic during UI tests.
        """))
    }

    func fetchLatestRelease(owner: String, repo: String) -> Single<RepositoryRelease?> {
        .just(RepositoryRelease(
            name: "Version 1.0",
            tagName: "v1.0",
            publishedAt: GitHubDateParser.date(from: "2026-04-05T10:00:00Z"),
            body: "Initial UI test release."
        ))
    }
}
