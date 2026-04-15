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

    private enum Constants {
        static let pageSize = 50
        static let promptMessage = L10n.Search.promptMessage
        static let emptyMessage = L10n.Search.emptyMessage
    }

    struct SearchState: Equatable {
        var query: String
        var repos: [Repo]
        var phase: SearchPhase
        var currentPage: Int
        var hasMorePages: Bool
        var isLoadingNextPage: Bool
    }

    enum SearchPhase: Equatable {
        case prompt(String)
        case loading
        case results
        case empty(String)
        case failure
    }

    private enum Action {
        case queryChanged(String)
        case initialLoaded(query: String, page: RepoPage)
        case initialFailed(query: String, message: String)
        case nextPageRequested(query: String)
        case nextPageLoaded(query: String, pageNumber: Int, page: RepoPage)
        case nextPageFailed(query: String, message: String)
    }

    struct Input {
        let username: Observable<String>
        let loadNextPage: Observable<Void>
    }

    struct Output {
        let state: Driver<SearchState>
        let alertMessage: Signal<String>
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
        let stateRelay = BehaviorRelay(value: Self.initialState)
        let username = input.username
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .distinctUntilChanged()
            .share(replay: 1, scope: .whileConnected)

        let initialActions = username
            .flatMapLatest { [service, scheduler, debounceInterval] name -> Observable<Action> in
                guard !name.isEmpty else {
                    return .just(.queryChanged(""))
                }

                let loading = Observable.just(Action.queryChanged(name))

                let request = Observable.just(name)
                    .debounce(debounceInterval, scheduler: scheduler)
                    .flatMap { query in
                        service.fetchRepos(username: query, page: 1, perPage: Constants.pageSize)
                            .asObservable()
                            .map { Action.initialLoaded(query: query, page: $0) }
                            .catch { error in
                                .just(.initialFailed(query: query, message: Self.mapError(error)))
                            }
                    }

                return Observable.concat(loading, request)
            }

        let nextPageActions = input.loadNextPage
            .withLatestFrom(stateRelay.asObservable())
            .filter { state in
                !state.query.isEmpty && state.hasMorePages && !state.isLoadingNextPage
            }
            .flatMapFirst { [service] state -> Observable<Action> in
                let nextPage = state.currentPage + 1
                let query = state.query
                let loading = Observable.just(Action.nextPageRequested(query: query))

                let request = service.fetchRepos(username: query, page: nextPage, perPage: Constants.pageSize)
                    .asObservable()
                    .map { Action.nextPageLoaded(query: query, pageNumber: nextPage, page: $0) }
                    .catch { error in
                        .just(.nextPageFailed(query: query, message: Self.mapError(error)))
                    }

                return Observable.concat(loading, request)
            }

        let actions = Observable.merge(initialActions, nextPageActions)
            .share(replay: 1, scope: .whileConnected)

        let state = actions
            .scan(Self.initialState, accumulator: Self.reduce)
            .startWith(Self.initialState)
            .do(onNext: stateRelay.accept)
            .asDriver(onErrorJustReturn: Self.initialState)

        let alertMessage = actions
            .compactMap { action -> String? in
                switch action {
                case let .initialFailed(_, message),
                     let .nextPageFailed(_, message):
                    return message
                default:
                    return nil
                }
            }
            .asSignal(onErrorSignalWith: .empty())

        return Output(
            state: state,
            alertMessage: alertMessage
        )
    }

    private static var initialState: SearchState {
        SearchState(
            query: "",
            repos: [],
            phase: .prompt(Constants.promptMessage),
            currentPage: 0,
            hasMorePages: false,
            isLoadingNextPage: false
        )
    }

    private static func reduce(state: SearchState, action: Action) -> SearchState {
        switch action {
        case let .queryChanged(query):
            return reduceQueryChanged(state: state, query: query)
        case let .initialLoaded(query, page):
            return reduceInitialLoaded(state: state, query: query, page: page)
        case let .initialFailed(query, _):
            return reduceInitialFailed(state: state, query: query)
        case let .nextPageRequested(query):
            return reduceNextPageRequested(state: state, query: query)
        case let .nextPageLoaded(query, pageNumber, page):
            return reduceNextPageLoaded(state: state, query: query, pageNumber: pageNumber, page: page)
        case let .nextPageFailed(query, _):
            return reduceNextPageFailed(state: state, query: query)
        }
    }

    private static func reduceQueryChanged(state: SearchState, query: String) -> SearchState {
        var state = state

        state.query = query
        state.repos = []
        state.currentPage = 0
        state.hasMorePages = false
        state.isLoadingNextPage = false
        state.phase = query.isEmpty
            ? .prompt(Constants.promptMessage)
            : .loading

        return state
    }

    private static func reduceInitialLoaded(state: SearchState, query: String, page: RepoPage) -> SearchState {
        var state = state

        guard state.query == query else {
            return state
        }
        state.repos = page.repos
        state.currentPage = 1
        state.hasMorePages = page.hasNextPage
        state.isLoadingNextPage = false
        state.phase = page.repos.isEmpty
            ? .empty(Constants.emptyMessage)
            : .results

        return state
    }

    private static func reduceInitialFailed(state: SearchState, query: String) -> SearchState {
        var state = state

        guard state.query == query else {
            return state
        }
        state.repos = []
        state.currentPage = 0
        state.hasMorePages = false
        state.isLoadingNextPage = false
        state.phase = .failure

        return state
    }

    private static func reduceNextPageRequested(state: SearchState, query: String) -> SearchState {
        var state = state

        guard state.query == query, state.hasMorePages else {
            return state
        }
        state.isLoadingNextPage = true

        return state
    }

    private static func reduceNextPageLoaded(
        state: SearchState,
        query: String,
        pageNumber: Int,
        page: RepoPage
    ) -> SearchState {
        var state = state

        guard state.query == query, state.isLoadingNextPage else {
            return state
        }
        state.repos += page.repos
        state.currentPage = pageNumber
        state.hasMorePages = page.hasNextPage
        state.isLoadingNextPage = false
        state.phase = state.repos.isEmpty
            ? .empty(Constants.emptyMessage)
            : .results

        return state
    }

    private static func reduceNextPageFailed(state: SearchState, query: String) -> SearchState {
        var state = state

        guard state.query == query else {
            return state
        }
        state.isLoadingNextPage = false

        return state
    }

    private static func mapError(_ error: Error) -> String {
        if let serviceError = error as? GitHubServiceError {
            return serviceError.userMessage
        }
        return L10n.Common.genericErrorMessage
    }

}
