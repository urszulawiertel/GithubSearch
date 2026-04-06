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
    private var state = SearchState()

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
        state = SearchState()

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

        bindUsername(username, relays: relays)
        bindDebouncedUsername(debouncedUsername, relays: relays)
        bindLoadNextPage(input.loadNextPage, relays: relays)

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
        relays: OutputRelays
    ) {
        username
            .subscribe(onNext: { [weak self] name in
                guard let self else { return }

                guard !name.isEmpty else {
                    self.state.currentQuery = ""
                    self.resetPagination()
                    relays.repos.accept([])
                    relays.viewState.accept(.prompt(Constants.promptMessage))
                    return
                }

                self.state.currentQuery = name
                self.resetPagination()
                relays.repos.accept([])
                relays.viewState.accept(.loading)
            })
            .disposed(by: disposeBag)
    }

    private func bindDebouncedUsername(
        _ debouncedUsername: Observable<String>,
        relays: OutputRelays
    ) {
        debouncedUsername
            .subscribe(onNext: { [weak self] name in
                guard let self else { return }

                guard self.state.currentQuery == name, !self.state.isPageLoadInProgress else {
                    return
                }

                self.loadPage(
                    PageLoadRequest(query: name, page: 1, isInitialLoad: true),
                    relays: relays
                )
            })
            .disposed(by: disposeBag)
    }

    private func bindLoadNextPage(
        _ loadNextPage: Observable<Void>,
        relays: OutputRelays
    ) {
        loadNextPage
            .subscribe(onNext: { [weak self] in
                guard let self else { return }

                guard !self.state.currentQuery.isEmpty, self.state.hasMorePages, !self.state.isPageLoadInProgress else {
                    return
                }

                self.loadPage(
                    PageLoadRequest(
                        query: self.state.currentQuery,
                        page: self.state.currentPage + 1,
                        isInitialLoad: false
                    ),
                    relays: relays
                )
            })
            .disposed(by: disposeBag)
    }

    private func resetPagination() {
        state.currentPage = 0
        state.currentRepos = []
        state.hasMorePages = false
        state.isPageLoadInProgress = false
    }

    private func applyLoadedPage(
        _ response: RepoPage,
        request: PageLoadRequest,
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
        relays: OutputRelays
    ) {
        state.isPageLoadInProgress = true

        service.fetchRepos(username: request.query, page: request.page, perPage: Constants.pageSize)
            .observe(on: scheduler)
            .subscribe(
                onSuccess: { [weak self] response in
                    guard let self else { return }

                    guard request.query == self.state.currentQuery else {
                        return
                    }

                    self.state.isPageLoadInProgress = false
                    self.applyLoadedPage(response, request: request, relays: relays)
                },
                onFailure: { [weak self] error in
                    guard let self else { return }

                    guard request.query == self.state.currentQuery else {
                        return
                    }

                    self.state.isPageLoadInProgress = false
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
