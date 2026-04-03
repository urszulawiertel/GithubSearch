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
    }

    struct Output {
        let viewState: Observable<ViewState>
        let repos: Observable<[Repo]>
        let errorMessage: Observable<String>
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

        let errorRelay = PublishRelay<String>()
        let viewState = makeViewState(username: username, errorRelay: errorRelay)
            .distinctUntilChanged()
            .share(replay: 1, scope: .whileConnected)

        return Output(
            viewState: viewState,
            repos: makeReposStream(viewState: viewState),
            errorMessage: errorRelay.asObservable()
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
    private static func mapReposToState(_ repos: [Repo]) -> ViewState {
        repos.isEmpty
            ? .empty("No public repositories found.")
            : .results(repos)
    }
}
