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
            .share(replay: 1)

        let isSearchEnabled = username
            .map { !$0.isEmpty }
            .distinctUntilChanged()

        let activity = ActivityIndicator()
        let errorRelay = PublishRelay<String>()

        let debouncedUsername = username
            .debounce(debounceInterval, scheduler: scheduler)
            .filter { !$0.isEmpty }
            .distinctUntilChanged()

        let reposStream = debouncedUsername
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
            .map { $0.isEmpty ? "No repositories found." : nil }
            .startWith("Type a username...")

        return Output(
            isSearchEnabled: isSearchEnabled,
            isLoading: activity.asObservable(),
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
