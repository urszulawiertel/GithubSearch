//
//  DebugGitHubService.swift
//  GithubSearch
//
//  Created by Ula on 03/07/2026.
//

#if DEBUG
import Foundation
import RxSwift

/// DEBUG-only service decorator that injects forced search outcomes before
/// falling through to the real GitHub service. Release builds do not compile it.
final class DebugGitHubService: GitHubServiceType {

    private let wrappedService: GitHubServiceType
    private let flags: DebugFlagProviding

    init(
        wrappedService: GitHubServiceType,
        flags: DebugFlagProviding = DebugSettings.shared
    ) {
        self.wrappedService = wrappedService
        self.flags = flags
    }

    func fetchRepos(username: String, page: Int, perPage: Int, sort: SearchSort) -> Single<RepoPage> {
        switch flags.searchResponseMode {
        case .live:
            return wrappedService.fetchRepos(username: username, page: page, perPage: perPage, sort: sort)
        case .empty:
            return .just(RepoPage(repos: [], hasNextPage: false))
        case .networkError:
            return .error(GitHubServiceError.connectivity)
        }
    }
}
#endif
