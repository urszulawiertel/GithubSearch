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

    enum ViewState: Equatable {
        case prompt(String)
        case loading
        case results([Repo])
        case empty(String)
        case failure
    }

    struct Input {
        let username: Observable<String>
        let selectedRepo: Observable<Repo>
    }

    struct Output {
        let isSearchEnabled: Observable<Bool>
        let viewState: Observable<ViewState>
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

        let errorRelay = PublishRelay<String>()
        let viewState = makeViewState(username: username, errorRelay: errorRelay)
            .distinctUntilChanged()
            .share(replay: 1, scope: .whileConnected)

        let loading = viewState
            .map { state in
                if case .loading = state {
                    return true
                }
                return false
            }
            .distinctUntilChanged()

        let reposStream = makeReposStream(viewState: viewState)
        let emptyMessage = makeEmptyMessage(viewState: viewState)

        return Output(
            isSearchEnabled: isSearchEnabled,
            viewState: viewState,
            isLoading: loading,
            repos: reposStream,
            emptyMessage: emptyMessage,
            errorMessage: errorRelay.asObservable(),
            openRepoDetails: input.selectedRepo
        )
    }

    private static func mapError(_ error: Error) -> String {
        if let serviceError = error as? GitHubServiceError {
            return serviceError.userMessage
        }
        return "Something went wrong. Please try again."
    }

    private func makeViewState(username: Observable<String>, errorRelay: PublishRelay<String>) -> Observable<ViewState> {
        username.flatMapLatest { [service, scheduler, debounceInterval] name -> Observable<ViewState> in
            guard !name.isEmpty else {
                return .just(.prompt("Enter a GitHub username"))
            }

            let searchResult = Observable<Int>
                .timer(debounceInterval, scheduler: scheduler)
                .flatMapLatest { _ in
                    service.fetchRepos(username: name)
                        .asObservable()
                        .map(Self.mapReposToState)
                        .catch { error in
                            errorRelay.accept(Self.mapError(error))
                            return .just(.failure)
                        }
                }

            return Observable.concat(
                .just(.loading),
                searchResult
            )
        }
    }

    private func makeReposStream(viewState: Observable<ViewState>) -> Observable<[Repo]> {
        viewState
            .map { state in
                if case let .results(repos) = state {
                    return repos
                }
                return []
            }
            .distinctUntilChanged()
    }

    private func makeEmptyMessage(viewState: Observable<ViewState>) -> Observable<String?> {
        viewState
            .map { state -> String? in
                switch state {
                case let .prompt(message), let .empty(message):
                    return message
                case .loading, .results, .failure:
                    return nil
                }
            }
            .distinctUntilChanged()
    }

    private static func mapReposToState(_ repos: [Repo]) -> ViewState {
        repos.isEmpty
            ? .empty("No public repositories found.")
            : .results(repos)
    }
}
