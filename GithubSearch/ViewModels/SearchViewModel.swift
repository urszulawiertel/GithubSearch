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
        let loadNextPage = input.loadNextPage

        let reposRelay = PublishRelay<[Repo]>()
        let viewStateRelay = PublishRelay<ViewState>()
        let errorRelay = PublishRelay<String>()

        var currentQuery = ""
        var currentPage = 0
        var currentRepos: [Repo] = []
        var hasMorePages = false
        var isPageLoadInProgress = false

        func resetPagination() {
            currentPage = 0
            currentRepos = []
            hasMorePages = false
            isPageLoadInProgress = false
        }

        func applyLoadedPage(_ response: RepoPage, page: Int, isInitialLoad: Bool) {
            currentRepos = isInitialLoad ? response.repos : currentRepos + response.repos
            currentPage = page
            hasMorePages = response.hasNextPage
            reposRelay.accept(currentRepos)
            viewStateRelay.accept(Self.mapReposToState(currentRepos))
        }

        func loadPage(query: String, page: Int, isInitialLoad: Bool) {
            isPageLoadInProgress = true

            service.fetchRepos(username: query, page: page, perPage: Constants.pageSize)
                .observe(on: scheduler)
                .subscribe(
                    onSuccess: { response in
                        guard query == currentQuery else {
                            return
                        }

                        isPageLoadInProgress = false
                        applyLoadedPage(response, page: page, isInitialLoad: isInitialLoad)
                    },
                    onFailure: { error in
                        guard query == currentQuery else {
                            return
                        }

                        isPageLoadInProgress = false
                        errorRelay.accept(Self.mapError(error))

                        if isInitialLoad {
                            viewStateRelay.accept(.failure)
                        }
                    }
                )
                .disposed(by: disposeBag)
        }

        username
            .subscribe(onNext: { name in
                guard !name.isEmpty else {
                    currentQuery = ""
                    resetPagination()
                    reposRelay.accept([])
                    viewStateRelay.accept(.prompt(Constants.promptMessage))
                    return
                }

                currentQuery = name
                resetPagination()
                reposRelay.accept([])
                viewStateRelay.accept(.loading)
            })
            .disposed(by: disposeBag)

        debouncedUsername
            .subscribe(onNext: { name in
                guard currentQuery == name, !isPageLoadInProgress else {
                    return
                }

                loadPage(query: name, page: 1, isInitialLoad: true)
            })
            .disposed(by: disposeBag)

        loadNextPage
            .subscribe(onNext: {
                guard !currentQuery.isEmpty, hasMorePages, !isPageLoadInProgress else {
                    return
                }

                loadPage(query: currentQuery, page: currentPage + 1, isInitialLoad: false)
            })
            .disposed(by: disposeBag)

        return Output(
            viewState: viewStateRelay
                .distinctUntilChanged()
                .asObservable(),
            repos: reposRelay
                .distinctUntilChanged()
                .asObservable(),
            errorMessage: errorRelay.asObservable()
        )
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
