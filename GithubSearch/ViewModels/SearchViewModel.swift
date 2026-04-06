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
        static let promptMessage = "Enter a GitHub username"
        static let emptyMessage = "No public repositories found."
    }

    private struct SearchState {
        var currentQuery = ""
        var currentPage = 0
        var currentRepos: [Repo] = []
        var hasMorePages = false
        var isPageLoadInProgress = false
    }

    private struct OutputRelays {
        let repos: PublishRelay<[Repo]>
        let viewState: PublishRelay<ViewState>
        let error: PublishRelay<String>
    }

    private struct PageLoadRequest {
        let query: String
        let page: Int
        let isInitialLoad: Bool
    }

    enum ViewState: Equatable {
        case prompt(String)
        case loading
        case results([Repo])
        case empty(String)
        case failure
    }

    struct Input {
        let username: Observable<String>
        let loadNextPage: Observable<Void>
    }

    struct Output {
        let viewState: Observable<ViewState>
        let repos: Observable<[Repo]>
        let errorMessage: Observable<String>
    }

    private let service: GitHubServiceType
    private let scheduler: SchedulerType
    private let debounceInterval: RxTimeInterval
    private let disposeBag = DisposeBag()

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
        let debouncedUsername = username
            .filter { !$0.isEmpty }
            .debounce(debounceInterval, scheduler: scheduler)
            .share(replay: 1, scope: .whileConnected)

        let relays = OutputRelays(
            repos: PublishRelay<[Repo]>(),
            viewState: PublishRelay<ViewState>(),
            error: PublishRelay<String>()
        )

        var state = SearchState()

        let getState = { state }
        let setState = { state = $0 }

        bindUsername(username, getState: getState, setState: setState, relays: relays)
        bindDebouncedUsername(debouncedUsername, getState: getState, setState: setState, relays: relays)
        bindLoadNextPage(input.loadNextPage, getState: getState, setState: setState, relays: relays)

        return Output(
            viewState: relays.viewState
                .distinctUntilChanged()
                .asObservable(),
            repos: relays.repos
                .distinctUntilChanged()
                .asObservable(),
            errorMessage: relays.error.asObservable()
        )
    }

    private func bindUsername(
        _ username: Observable<String>,
        getState: @escaping () -> SearchState,
        setState: @escaping (SearchState) -> Void,
        relays: OutputRelays
    ) {
        username
            .subscribe(onNext: { [weak self] name in
                guard let self else { return }

                var state = getState()

                guard !name.isEmpty else {
                    state.currentQuery = ""
                    self.resetPagination(state: &state)
                    setState(state)
                    relays.repos.accept([])
                    relays.viewState.accept(.prompt(Constants.promptMessage))
                    return
                }

                state.currentQuery = name
                self.resetPagination(state: &state)
                setState(state)
                relays.repos.accept([])
                relays.viewState.accept(.loading)
            })
            .disposed(by: disposeBag)
    }

    private func bindDebouncedUsername(
        _ debouncedUsername: Observable<String>,
        getState: @escaping () -> SearchState,
        setState: @escaping (SearchState) -> Void,
        relays: OutputRelays
    ) {
        debouncedUsername
            .subscribe(onNext: { [weak self] name in
                guard let self else { return }

                let state = getState()

                guard state.currentQuery == name, !state.isPageLoadInProgress else {
                    return
                }

                self.loadPage(
                    PageLoadRequest(query: name, page: 1, isInitialLoad: true),
                    getState: getState,
                    setState: setState,
                    relays: relays
                )
            })
            .disposed(by: disposeBag)
    }

    private func bindLoadNextPage(
        _ loadNextPage: Observable<Void>,
        getState: @escaping () -> SearchState,
        setState: @escaping (SearchState) -> Void,
        relays: OutputRelays
    ) {
        loadNextPage
            .subscribe(onNext: { [weak self] in
                guard let self else { return }

                let state = getState()

                guard !state.currentQuery.isEmpty, state.hasMorePages, !state.isPageLoadInProgress else {
                    return
                }

                self.loadPage(
                    PageLoadRequest(
                        query: state.currentQuery,
                        page: state.currentPage + 1,
                        isInitialLoad: false
                    ),
                    getState: getState,
                    setState: setState,
                    relays: relays
                )
            })
            .disposed(by: disposeBag)
    }

    private func resetPagination(state: inout SearchState) {
        state.currentPage = 0
        state.currentRepos = []
        state.hasMorePages = false
        state.isPageLoadInProgress = false
    }

    private func applyLoadedPage(
        _ response: RepoPage,
        request: PageLoadRequest,
        state: inout SearchState,
        relays: OutputRelays
    ) {
        state.currentRepos = request.isInitialLoad ? response.repos : state.currentRepos + response.repos
        state.currentPage = request.page
        state.hasMorePages = response.hasNextPage
        relays.repos.accept(state.currentRepos)
        relays.viewState.accept(Self.mapReposToState(state.currentRepos))
    }

    private func loadPage(
        _ request: PageLoadRequest,
        getState: @escaping () -> SearchState,
        setState: @escaping (SearchState) -> Void,
        relays: OutputRelays
    ) {
        var loadingState = getState()
        loadingState.isPageLoadInProgress = true
        setState(loadingState)

        service.fetchRepos(username: request.query, page: request.page, perPage: Constants.pageSize)
            .observe(on: scheduler)
            .subscribe(
                onSuccess: { response in
                    var state = getState()

                    guard request.query == state.currentQuery else {
                        return
                    }

                    state.isPageLoadInProgress = false
                    self.applyLoadedPage(response, request: request, state: &state, relays: relays)
                    setState(state)
                },
                onFailure: { error in
                    var state = getState()

                    guard request.query == state.currentQuery else {
                        return
                    }

                    state.isPageLoadInProgress = false
                    setState(state)
                    relays.error.accept(Self.mapError(error))

                    if request.isInitialLoad {
                        relays.viewState.accept(.failure)
                    }
                }
            )
            .disposed(by: disposeBag)
    }

    private static func mapError(_ error: Error) -> String {
        if let serviceError = error as? GitHubServiceError {
            return serviceError.userMessage
        }
        return "Something went wrong. Please try again."
    }

    private static func mapReposToState(_ repos: [Repo]) -> ViewState {
        repos.isEmpty
            ? .empty(Constants.emptyMessage)
            : .results(repos)
    }
}
