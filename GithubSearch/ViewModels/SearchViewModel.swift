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
        let isSearchEnabled: Driver<Bool>
        let isLoading: Driver<Bool>
        let repos: Driver<[Repo]>
        let errorMessage: Driver<String?>
        let emptyMessage: Driver<String?>
        let openRepoURL: Signal<URL>
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
            .asDriver(onErrorJustReturn: false)

        let openRepoURL = input.selectedRepo
            .map(\.htmlUrl)
            .asSignal(onErrorSignalWith: .empty())

        let activity = ActivityIndicator()
        let errorRelay = PublishRelay<String?>()

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

        let errorMessage = errorRelay
            .startWith(nil)
            .asDriver(onErrorJustReturn: "Unknown error")

        let emptyMessage = reposStream
            .map { repos -> String? in
                repos.isEmpty ? "No repositories found." : nil
            }
            .startWith("Type a username and search.")
            .asDriver(onErrorJustReturn: nil)

        return Output(
            isSearchEnabled: isSearchEnabled,
            isLoading: activity.asDriver(),
            repos: reposStream.asDriver(onErrorJustReturn: []),
            errorMessage: errorMessage,
            emptyMessage: emptyMessage,
            openRepoURL: openRepoURL
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
