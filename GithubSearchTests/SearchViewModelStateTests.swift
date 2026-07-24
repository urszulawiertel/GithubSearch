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

    func test_repos_clearWhenDebouncedUsernameIsAccepted() {
        let service = GitHubServiceMock()
        let repos = [Repo.mock(name: "Repo1"), Repo.mock(name: "Repo2")]
        service.stubbedPage = RepoPage(repos: repos, hasNextPage: false)

        let viewModel = makeViewModel(service: service)
        let output = viewModel.transform(input: makeInput(usernameEvents: [
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

        XCTAssertEqual(observer.events.compactMap { $0.value.element }, [[], repos, [], repos])
        XCTAssertEqual(observer.events.map(\.time), [0, 410, 900, 900])
    }

    func test_phase_startsLoadingAtDebouncedBoundary_forNonEmptyQueryChanges() {
        let service = GitHubServiceMock()
        service.stubbedPage = RepoPage(repos: [Repo.mock(name: "Repo1")], hasNextPage: false)

        let viewModel = makeViewModel(service: service)
        let output = viewModel.transform(input: makeInput(usernameEvents: [
            .next(10, "apple"),
            .next(500, "microsoft"),
            .next(1_100, "")
        ]))

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
            [.prompt(L10n.Search.promptMessage), .loading, .results, .loading, .results, .prompt(L10n.Search.promptMessage)]
        )
        XCTAssertEqual(observer.events.map(\.time), [0, 410, 410, 900, 900, 1_100])
    }

    func test_phase_emitsFailure_andAlertMessage_whenFetchFails() {
        let service = GitHubServiceMock()
        service.stubbedError = GitHubServiceError.userNotFound

        let viewModel = makeViewModel(service: service)
        let output = viewModel.transform(input: makeInput(usernameEvents: [
            .next(10, "ghost-user")
        ]))

        let stateObserver = scheduler.createObserver(SearchViewModel.SearchPhase.self)
        let errorObserver = scheduler.createObserver(String.self)

        output.state
            .asObservable()
            .map(\.phase)
            .distinctUntilChanged()
            .subscribe(stateObserver)
            .disposed(by: disposeBag)

        output.alertMessage
            .asObservable()
            .subscribe(errorObserver)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(stateObserver.events.compactMap { $0.value.element }, [.prompt(L10n.Search.promptMessage), .loading, .failure])
        XCTAssertEqual(stateObserver.events.map(\.time), [0, 410, 410])
        XCTAssertEqual(errorObserver.events.compactMap { $0.value.element }, [L10n.GitHubServiceError.userNotFound])
    }

    func test_repos_clearImmediately_whenUsernameBecomesEmptyString() {
        let service = GitHubServiceMock()
        let repos = [Repo.mock(name: "Repo1"), Repo.mock(name: "Repo2")]
        service.stubbedPage = RepoPage(repos: repos, hasNextPage: false)

        let viewModel = makeViewModel(service: service)
        let output = viewModel.transform(input: makeInput(usernameEvents: [
            .next(10, "apple"),
            .next(500, "")
        ]))

        let observer = scheduler.createObserver([Repo].self)

        output.state
            .asObservable()
            .map(\.repos)
            .distinctUntilChanged()
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(observer.events.compactMap { $0.value.element }, [[], repos, []])
    }

    func test_clearingUsername_cancelsPendingSearch_andResetsStateImmediately() {
        let service = GitHubServiceMock()
        let repos = [Repo.mock(name: "AppleRepo")]
        service.stubbedPage = RepoPage(repos: repos, hasNextPage: false)

        let output = makeViewModel(service: service).transform(input: makeInput(usernameEvents: [
            .next(10, "apple"),
            .next(500, "Zaydla"),
            .next(600, "   ")
        ]))
        let observer = scheduler.createObserver(SearchViewModel.SearchState.self)

        output.state
            .asObservable()
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        let reset = observer.events.first { event in
            event.time == 600 && event.value.element?.query == ""
        }?.value.element

        XCTAssertEqual(service.fetchReposCallCount, 1)
        XCTAssertEqual(service.lastUsername, "apple")
        XCTAssertEqual(reset?.repos, [])
        XCTAssertEqual(reset?.phase, .prompt(L10n.Search.promptMessage))
    }

    func test_staleUsernameResponse_doesNotReplaceLatestResults() {
        let service = GitHubServiceMock()
        let appleRepos = [Repo.mock(id: 1, name: "AppleRepo")]
        let zaydlaRepos = [Repo.mock(id: 2, name: "ZaydlaRepo")]
        let scheduler = self.scheduler!

        service.fetchReposHandler = { username, _, _, _ in
            let response: Recorded<Event<RepoPage>>

            switch username {
            case "apple":
                response = .next(600, RepoPage(repos: appleRepos, hasNextPage: false))
            default:
                response = .next(10, RepoPage(repos: zaydlaRepos, hasNextPage: false))
            }

            return scheduler.createColdObservable([
                response,
                .completed(response.time)
            ]).asSingle()
        }

        let output = makeViewModel(service: service).transform(input: makeInput(usernameEvents: [
            .next(10, "apple"),
            .next(500, "Zaydla")
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
        XCTAssertEqual(
            observer.events,
            [
                .next(0, []),
                .next(910, zaydlaRepos)
            ]
        )
    }

    private func makeViewModel(service: GitHubServiceMock) -> SearchViewModel {
        SearchViewModel(
            service: service,
            scheduler: scheduler,
            debounceInterval: .milliseconds(400)
        )
    }

    private func makeInput(usernameEvents: [Recorded<Event<String>>]) -> SearchViewModel.Input {
        let username = scheduler.createHotObservable(usernameEvents).asObservable()

        return .init(
            username: username,
            sortChanged: .empty(),
            loadNextPage: .empty()
        )
    }
}
