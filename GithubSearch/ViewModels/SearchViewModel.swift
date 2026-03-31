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
    private let scheduler: SchedulerType
    private let debounceInterval: RxTimeInterval

    init(
        service: GitHubServiceType = GitHubService(),
        scheduler: SchedulerType = MainScheduler.instance,
        debounceInterval: RxTimeInterval = .milliseconds(400)
    ) {
        self.service = service
        self.scheduler = scheduler
        self.debounceInterval = debounceInterval
    }

    func transform(input: Input) -> Output {
        let username = input.username
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .distinctUntilChanged()
            .share(replay: 1, scope: .whileConnected)

        let isSearchEnabled = username
            .map { !$0.isEmpty }
            .distinctUntilChanged()

        let activity = ActivityIndicator()
        let errorRelay = PublishRelay<String>()
        let didFail = PublishRelay<Void>()

        let debouncedUsername = username
            .debounce(debounceInterval, scheduler: scheduler)
            .distinctUntilChanged()
            .share(replay: 1, scope: .whileConnected)

        let fetchedRepos = debouncedUsername
            .filter { !$0.isEmpty }
            .flatMapLatest { [service] name in
                service.fetchRepos(username: name)
                    .trackActivity(activity)
                    .asObservable()
                    .catch { error in
                        errorRelay.accept(Self.mapError(error))
                        didFail.accept(())
                        return .just([])
                    }
            }
            .share(replay: 1, scope: .whileConnected)

        let clearedRepos = username
            .filter { $0.isEmpty }
            .map { _ in [Repo]() }

        let reposStream = Observable.merge(clearedRepos, fetchedRepos)
            .share(replay: 1, scope: .whileConnected)

        let loading = activity.asObservable()
            .distinctUntilChanged()
            .share(replay: 1, scope: .whileConnected)

        let promptMessage = username
            .map { $0.isEmpty ? "Type a username..." : nil }
            .distinctUntilChanged()

        let searchFailed = Observable.merge(
            debouncedUsername.map { _ in false },
            didFail.map { _ in true }
        )
        .startWith(false)
        .distinctUntilChanged()

        let noResultsMessage: Observable<String?> = Observable
            .combineLatest(
                debouncedUsername,
                fetchedRepos,
                loading,
                searchFailed
            )
            .map { name, repos, isLoading, didFail in
                guard !name.isEmpty else { return nil }
                guard !isLoading else { return nil }
                guard !didFail else { return nil }
                return repos.isEmpty ? "No repositories found." : nil
            }
            .distinctUntilChanged()

        let emptyMessage = Observable.merge(
            promptMessage,
            noResultsMessage
        )
        .distinctUntilChanged()

        return Output(
            isSearchEnabled: isSearchEnabled,
            isLoading: loading,
            repos: reposStream,
            emptyMessage: emptyMessage,
            errorMessage: errorRelay.asObservable(),
            openRepoDetails: input.selectedRepo
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
