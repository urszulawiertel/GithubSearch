//
//  SearchViewModelStateTests.swift
//  GithubSearchTests
//
//  Created by Codex on 31/03/2026.
//

import XCTest
import RxSwift
import RxTest
@testable import GithubSearch

final class SearchViewModelStateTests: XCTestCase {

    private var disposeBag: DisposeBag!
    private var scheduler: TestScheduler!

    override func setUp() {
        super.setUp()
        disposeBag = DisposeBag()
        scheduler = TestScheduler(initialClock: 0, resolution: 0.001)
    }

    override func tearDown() {
        disposeBag = nil
        scheduler = nil
        super.tearDown()
    }

    func test_userNotFoundError_producesUserNotFoundState() {
        let service = GitHubServiceMock()
        service.stubbedError = GitHubServiceError.userNotFound
        let output = makeViewModel(service: service).transform(
            input: makeInput(usernameEvents: [.next(10, "ghost-user")])
        )
        let observer = scheduler.createObserver(SearchViewModel.SearchPhase.self)

        output.state
            .asObservable()
            .map(\.phase)
            .distinctUntilChanged()
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(
            observer.events.compactMap { $0.value.element },
            [.prompt(L10n.Search.promptMessage), .idle, .loading, .userNotFound]
        )
    }

    func test_userNotFoundError_doesNotProduceGeneralFailureOrAlert() {
        let service = GitHubServiceMock()
        service.stubbedError = GitHubServiceError.userNotFound
        let output = makeViewModel(service: service).transform(
            input: makeInput(usernameEvents: [.next(10, "ghost-user")])
        )
        let stateObserver = scheduler.createObserver(SearchViewModel.SearchPhase.self)
        let alertObserver = scheduler.createObserver(String.self)

        output.state
            .asObservable()
            .map(\.phase)
            .subscribe(stateObserver)
            .disposed(by: disposeBag)
        output.alertMessage
            .asObservable()
            .subscribe(alertObserver)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertFalse(stateObserver.events.compactMap { $0.value.element }.contains(.failure))
        XCTAssertTrue(alertObserver.events.compactMap { $0.value.element }.isEmpty)
    }

    func test_userNotFoundError_clearsPreviousResults() {
        let service = GitHubServiceMock()
        let repos = [Repo.mock(name: "AppleRepo")]
        service.fetchReposHandler = { username, _, _, _ in
            username == "apple"
                ? .just(RepoPage(repos: repos, hasNextPage: true))
                : .error(GitHubServiceError.userNotFound)
        }
        let output = makeViewModel(service: service).transform(input: makeInput(usernameEvents: [
            .next(10, "apple"),
            .next(500, "ghost-user")
        ]))
        let observer = scheduler.createObserver(SearchViewModel.SearchState.self)

        output.state
            .asObservable()
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        let finalState = observer.events.compactMap { $0.value.element }.last
        XCTAssertEqual(finalState?.phase, .userNotFound)
        XCTAssertEqual(finalState?.repos, [])
        XCTAssertEqual(finalState?.currentPage, 0)
        XCTAssertEqual(finalState?.hasMorePages, false)
        XCTAssertEqual(finalState?.isLoadingNextPage, false)
    }

    func test_queryChange_clearsUserNotFoundAndResultsImmediately_duringDebounce() {
        let service = GitHubServiceMock()
        let repos = [Repo.mock(name: "AppleRepo")]
        service.fetchReposHandler = { username, _, _, _ in
            username == "apple"
                ? .just(RepoPage(repos: repos, hasNextPage: false))
                : .error(GitHubServiceError.userNotFound)
        }
        let output = makeViewModel(service: service).transform(input: makeInput(usernameEvents: [
            .next(10, "apple"),
            .next(500, "ghost-user"),
            .next(1_000, "octocat")
        ]))
        let observer = scheduler.createObserver(SearchViewModel.SearchState.self)

        output.state
            .asObservable()
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.advanceTo(1_000)

        let stateAfterResults = observer.events.first {
            $0.time == 500 && $0.value.element?.query == "ghost-user"
        }?.value.element
        XCTAssertEqual(stateAfterResults?.phase, .idle)
        XCTAssertEqual(stateAfterResults?.repos, [])

        let stateAfterUserNotFound = observer.events.first {
            $0.time == 1_000 && $0.value.element?.query == "octocat"
        }?.value.element
        XCTAssertEqual(stateAfterUserNotFound?.phase, .idle)
        XCTAssertEqual(stateAfterUserNotFound?.repos, [])
        XCTAssertFalse(stateAfterUserNotFound?.isLoadingNextPage ?? true)
    }

    func test_emptyAndWhitespaceOnlyInput_resetImmediately_withoutRequest() {
        let service = GitHubServiceMock()
        let repos = [Repo.mock(name: "AppleRepo")]
        service.stubbedPage = RepoPage(repos: repos, hasNextPage: true)
        let output = makeViewModel(service: service).transform(input: makeInput(usernameEvents: [
            .next(10, "apple"),
            .next(500, ""),
            .next(600, "   ")
        ]))
        let observer = scheduler.createObserver(SearchViewModel.SearchState.self)

        output.state
            .asObservable()
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        let resetState = observer.events.first {
            $0.time == 500 && $0.value.element?.query == ""
        }?.value.element
        XCTAssertEqual(service.fetchReposCallCount, 1)
        XCTAssertEqual(resetState?.repos, [])
        XCTAssertEqual(resetState?.phase, .prompt(L10n.Search.promptMessage))
        XCTAssertEqual(resetState?.currentPage, 0)
        XCTAssertEqual(resetState?.hasMorePages, false)
        XCTAssertEqual(resetState?.isLoadingNextPage, false)
    }

    func test_successfulSearchAfterUserNotFound_displaysResults() {
        let service = GitHubServiceMock()
        let repos = [Repo.mock(name: "OctocatRepo")]
        service.fetchReposHandler = { username, _, _, _ in
            username == "ghost-user"
                ? .error(GitHubServiceError.userNotFound)
                : .just(RepoPage(repos: repos, hasNextPage: false))
        }
        let output = makeViewModel(service: service).transform(input: makeInput(usernameEvents: [
            .next(10, "ghost-user"),
            .next(500, "octocat")
        ]))
        let observer = scheduler.createObserver(SearchViewModel.SearchState.self)

        output.state
            .asObservable()
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        let finalState = observer.events.compactMap { $0.value.element }.last
        XCTAssertEqual(finalState?.phase, .results)
        XCTAssertEqual(finalState?.repos, repos)
    }

    func test_connectivityError_remainsGeneralFailureAndEmitsAlert() {
        let service = GitHubServiceMock()
        service.stubbedError = GitHubServiceError.connectivity
        let output = makeViewModel(service: service).transform(
            input: makeInput(usernameEvents: [.next(10, "octocat")])
        )
        let stateObserver = scheduler.createObserver(SearchViewModel.SearchPhase.self)
        let alertObserver = scheduler.createObserver(String.self)

        output.state
            .asObservable()
            .map(\.phase)
            .distinctUntilChanged()
            .subscribe(stateObserver)
            .disposed(by: disposeBag)
        output.alertMessage
            .asObservable()
            .subscribe(alertObserver)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(stateObserver.events.compactMap { $0.value.element }.last, .failure)
        XCTAssertEqual(
            alertObserver.events.compactMap { $0.value.element },
            [L10n.GitHubServiceError.connectivity]
        )
    }

    func test_staleResponse_cannotRepopulateCurrentQuery() {
        let service = GitHubServiceMock()
        let staleRepos = [Repo.mock(id: 1, name: "StaleRepo")]
        let currentRepos = [Repo.mock(id: 2, name: "CurrentRepo")]
        let scheduler = self.scheduler!
        service.fetchReposHandler = { username, _, _, _ in
            let delay = username == "apple" ? 600 : 10
            let repos = username == "apple" ? staleRepos : currentRepos
            return scheduler.createColdObservable([
                .next(delay, RepoPage(repos: repos, hasNextPage: false)),
                .completed(delay)
            ]).asSingle()
        }
        let output = makeViewModel(service: service).transform(input: makeInput(usernameEvents: [
            .next(10, "apple"),
            .next(500, "microsoft")
        ]))
        let observer = scheduler.createObserver([Repo].self)

        output.state
            .asObservable()
            .map(\.repos)
            .distinctUntilChanged()
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(service.fetchReposCallCount, 2)
        XCTAssertEqual(observer.events.compactMap { $0.value.element }, [[], currentRepos])
        XCTAssertFalse(observer.events.compactMap { $0.value.element }.contains(staleRepos))
    }

    private func makeViewModel(service: GitHubServiceMock) -> SearchViewModel {
        SearchViewModel(
            service: service,
            scheduler: scheduler,
            debounceInterval: .milliseconds(400)
        )
    }

    private func makeInput(usernameEvents: [Recorded<Event<String>>]) -> SearchViewModel.Input {
        .init(
            username: scheduler.createHotObservable(usernameEvents).asObservable(),
            sortChanged: .empty(),
            loadNextPage: .empty()
        )
    }
}
