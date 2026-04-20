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
            return GitHubService()
        }

        return UITestGitHubService(scenario: scenario)
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
                        language: "Swift",
                        htmlUrl: URL(string: "https://github.com/\(username)/ios-github-search")!,
                        owner: nil
                    )
                ],
                hasNextPage: false
            ))
        case .empty:
            return .just(RepoPage(repos: [], hasNextPage: false))
        }
    }
}
