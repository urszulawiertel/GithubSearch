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
        let searchTap: Signal<Void>
        let selectedRepo: Signal<Repo>
    }

    struct Output {
        let isSearchEnabled: Driver<Bool>
        let isLoading: Driver<Bool>
        let repos: Driver<[Repo]>
        let errorMessage: Signal<String>
        let emptyMessage: Driver<String?>
        let openRepoURL: Signal<URL>
        let openRepoDetails: Signal<Repo>
    }

    private let service: GitHubServiceType

    init(service: GitHubServiceType = GitHubService()) {
        self.service = service
    }

    func transform(input: Input) -> Output {

        // 1) sanitize username
        let usernameObservable = input.username
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .distinctUntilChanged()
            .share(replay: 1)

        let isSearchEnabled = usernameObservable
            .map { !$0.isEmpty }
            .asDriver(onErrorJustReturn: false)

        // 2) Convert username -> Signal so it can be used with Signal.withLatestFrom
        let usernameSignal = usernameObservable
            .asSignal(onErrorSignalWith: .empty())

        let activity = ActivityIndicator()
        let errorRelay = PublishRelay<String>()

        // 3) search trigger (Signal) + latest username (Signal)
        let searchUsername = input.searchTap
            .withLatestFrom(usernameSignal)
            .filter { !$0.isEmpty }

        // 4) Repos stream
        let reposStream = searchUsername
            .flatMapLatest { [service] name in
                service.fetchRepos(username: name)
                    .trackActivity(activity)
                    .do(onError: { error in
                        errorRelay.accept(Self.mapError(error))
                    })
                    .catchAndReturn([])
                    .asSignal(onErrorSignalWith: .just([])) // keep it UI-friendly
            }
            .asDriver(onErrorJustReturn: [])

        // 5) UI messages
        let emptyMessage = reposStream
            .map { repos -> String? in
                repos.isEmpty ? "No repositories found." : nil
            }
            .startWith("Type a username and search.")

        let errorMessage = errorRelay
            .asSignal()

        // 6) Navigation outputs
        let openRepoDetails = input.selectedRepo

        let openRepoURL = input.selectedRepo
            .map(\.htmlUrl)

        return Output(
            isSearchEnabled: isSearchEnabled,
            isLoading: activity.asDriver(),
            repos: reposStream,
            errorMessage: errorMessage,
            emptyMessage: emptyMessage,
            openRepoURL: openRepoURL,
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
