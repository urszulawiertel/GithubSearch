//
//  SearchViewModel.swift
//  GithubSearch
//
//  Created by Ula on 17/02/2026.
//

import Foundation
import RxSwift
import RxCocoa

final class SearchViewModel {

    struct Input {
        let username: Observable<String>
        let searchTap: Observable<Void>
        let selectedRepo: Observable<Repo>
    }

    struct Output {
        let isSearchEnabled: Observable<Bool>
        let isLoading: Observable<Bool>
        let repos: Observable<[Repo]>
        let emptyMessage: Observable<String?>
        let errorMessage: Observable<String>
        let openRepoDetails: Observable<Repo>
    }

    private let service: GitHubServiceType

    init(service: GitHubServiceType = GitHubService()) {
        self.service = service
    }

    func transform(input: Input) -> Output {
        let username = input.username
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .share(replay: 1)

        let isSearchEnabled = username
            .map { !$0.isEmpty }
            .distinctUntilChanged()

        let activity = ActivityIndicator()
        let errorRelay = PublishRelay<String>()

        let searchUsername = input.searchTap
            .withLatestFrom(username)
            .filter { !$0.isEmpty }

        let reposStream = searchUsername
            .flatMapLatest { [service] name in
                service.fetchRepos(username: name)
                    .trackActivity(activity)
                    .asObservable()
                    .catch { error in
                        errorRelay.accept(Self.mapError(error))
                        return .just([])
                    }
            }
            .share(replay: 1)

        let emptyMessage: Observable<String?> = reposStream
            .map { repos -> String? in
                repos.isEmpty ? "No repositories found." : nil
            }
            .startWith("Type a username and search.")

        let openRepoDetails = input.selectedRepo

        return Output(
            isSearchEnabled: isSearchEnabled,
            isLoading: activity.asObservable(),
            repos: reposStream,
            emptyMessage: emptyMessage,
            errorMessage: errorRelay.asObservable(),
            openRepoDetails: openRepoDetails
        )
    }

    private static func mapError(_ error: Error) -> String {
        if let serviceError = error as? GitHubServiceError {
            switch serviceError {
            case .invalidURL: return "Invalid username."
            case .http(let code): return "HTTP error: \(code)"
            case .decoding: return "Failed to decode response."
            }
        }
        return "Network error."
    }
}
