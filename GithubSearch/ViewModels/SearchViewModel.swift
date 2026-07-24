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
        var selectedSort: SearchSort
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
        case parametersChanged(SearchParameters)
        case initialLoaded(parameters: SearchParameters, page: RepoPage)
        case initialFailed(parameters: SearchParameters, message: String)
        case nextPageRequested(parameters: SearchParameters)
        case nextPageLoaded(parameters: SearchParameters, pageNumber: Int, page: RepoPage)
        case nextPageFailed(parameters: SearchParameters, message: String)
    }

    fileprivate struct SearchParameters: Equatable {
        let query: String
        let sort: SearchSort
    }

    struct Input {
        let username: Observable<String>
        let sortChanged: Observable<SearchSort>
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
        debounceInterval: RxTimeInterval = .milliseconds(500)
    ) {
        self.service = service
        self.scheduler = scheduler
        self.debounceInterval = debounceInterval
    }

    func transform(input: Input) -> Output {
        let stateRelay = BehaviorRelay(value: Self.initialState)
        let normalizedUsername = input.username
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .distinctUntilChanged()
            .share(replay: 1, scope: .whileConnected)
        let username = Observable.merge(
            normalizedUsername.filter(\.isEmpty),
            normalizedUsername
                .debounce(debounceInterval, scheduler: scheduler)
                .filter { !$0.isEmpty }
        )
            .distinctUntilChanged()
            .share(replay: 1, scope: .whileConnected)
        let selectedSort = input.sortChanged
            .startWith(Self.initialState.selectedSort)
            .distinctUntilChanged()
            .share(replay: 1, scope: .whileConnected)
        let searchParameters = Observable
            .combineLatest(username, selectedSort) { query, sort in
                SearchParameters(query: query, sort: sort)
            }
            .distinctUntilChanged()
            .share(replay: 1, scope: .whileConnected)

        let initialActions = searchParameters
            .flatMapLatest { [service] parameters -> Observable<Action> in
                guard !parameters.query.isEmpty else {
                    return .just(.parametersChanged(parameters))
                }

                let request = Observable.deferred {
                    service.fetchRepos(
                        username: parameters.query,
                        page: 1,
                        perPage: Constants.pageSize,
                        sort: parameters.sort
                    )
                        .asObservable()
                        .map { Action.initialLoaded(parameters: parameters, page: $0) }
                        .catch { error in
                            .just(.initialFailed(parameters: parameters, message: Self.mapError(error)))
                        }
                }

                return Observable.concat(.just(.parametersChanged(parameters)), request)
            }

        let nextPageActions = input.loadNextPage
            .withLatestFrom(stateRelay.asObservable())
            .filter { state in
                !state.query.isEmpty && state.hasMorePages && !state.isLoadingNextPage
            }
            .flatMapFirst { [service] state -> Observable<Action> in
                let nextPage = state.currentPage + 1
                let parameters = SearchParameters(query: state.query, sort: state.selectedSort)
                let loading = Observable.just(Action.nextPageRequested(parameters: parameters))

                let request = service.fetchRepos(
                    username: parameters.query,
                    page: nextPage,
                    perPage: Constants.pageSize,
                    sort: parameters.sort
                )
                    .asObservable()
                    .map { Action.nextPageLoaded(parameters: parameters, pageNumber: nextPage, page: $0) }
                    .catch { error in
                        .just(.nextPageFailed(parameters: parameters, message: Self.mapError(error)))
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
            selectedSort: .bestMatch,
            repos: [],
            phase: .prompt(Constants.promptMessage),
            currentPage: 0,
            hasMorePages: false,
            isLoadingNextPage: false
        )
    }

    private static func reduce(state: SearchState, action: Action) -> SearchState {
        switch action {
        case let .parametersChanged(parameters):
            return reduceParametersChanged(state: state, parameters: parameters)
        case let .initialLoaded(parameters, page):
            return reduceInitialLoaded(state: state, parameters: parameters, page: page)
        case let .initialFailed(parameters, _):
            return reduceInitialFailed(state: state, parameters: parameters)
        case let .nextPageRequested(parameters):
            return reduceNextPageRequested(state: state, parameters: parameters)
        case let .nextPageLoaded(parameters, pageNumber, page):
            return reduceNextPageLoaded(state: state, parameters: parameters, pageNumber: pageNumber, page: page)
        case let .nextPageFailed(parameters, _):
            return reduceNextPageFailed(state: state, parameters: parameters)
        }
    }

    private static func reduceParametersChanged(state: SearchState, parameters: SearchParameters) -> SearchState {
        var state = state

        state.query = parameters.query
        state.selectedSort = parameters.sort
        state.repos = []
        state.currentPage = 0
        state.hasMorePages = false
        state.isLoadingNextPage = false
        state.phase = parameters.query.isEmpty
            ? .prompt(Constants.promptMessage)
            : .loading

        return state
    }

    private static func reduceInitialLoaded(state: SearchState, parameters: SearchParameters, page: RepoPage) -> SearchState {
        var state = state

        guard state.matches(parameters) else {
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

    private static func reduceInitialFailed(state: SearchState, parameters: SearchParameters) -> SearchState {
        var state = state

        guard state.matches(parameters) else {
            return state
        }
        state.repos = []
        state.currentPage = 0
        state.hasMorePages = false
        state.isLoadingNextPage = false
        state.phase = .failure

        return state
    }

    private static func reduceNextPageRequested(state: SearchState, parameters: SearchParameters) -> SearchState {
        var state = state

        guard state.matches(parameters), state.hasMorePages else {
            return state
        }
        state.isLoadingNextPage = true

        return state
    }

    private static func reduceNextPageLoaded(
        state: SearchState,
        parameters: SearchParameters,
        pageNumber: Int,
        page: RepoPage
    ) -> SearchState {
        var state = state

        guard state.matches(parameters), state.isLoadingNextPage else {
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

    private static func reduceNextPageFailed(state: SearchState, parameters: SearchParameters) -> SearchState {
        var state = state

        guard state.matches(parameters) else {
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

private extension SearchViewModel.SearchState {
    func matches(_ parameters: SearchViewModel.SearchParameters) -> Bool {
        query == parameters.query && selectedSort == parameters.sort
    }
}
