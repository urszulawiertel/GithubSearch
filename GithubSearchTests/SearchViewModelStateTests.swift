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
        scheduler = TestScheduler(initialClock: 0)
    }

    override func tearDown() {
        disposeBag = nil
        scheduler = nil
        super.tearDown()
    }

    func test_repos_clearImmediately_whenUsernameChangesToNewNonEmptyValue() {
        let service = GitHubServiceMock()
        let repos = [Repo.mock(name: "Repo1"), Repo.mock(name: "Repo2")]
        service.stubbedPage = RepoPage(repos: repos, hasNextPage: false)

        let viewModel = makeViewModel(service: service)
        let output = viewModel.transform(input: makeInput(usernameEvents: [
            .next(10, "apple"),
            .next(500, "microsoft")
        ]))

        let observer = scheduler.createObserver([Repo].self)

        output.repos
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(observer.events.compactMap { $0.value.element }, [[], repos, [], repos])
    }

    func test_viewState_startsImmediately_withLoading_forNonEmptyQueryChanges() {
        let service = GitHubServiceMock()
        service.stubbedPage = RepoPage(repos: [Repo.mock(name: "Repo1")], hasNextPage: false)

        let viewModel = makeViewModel(service: service)
        let output = viewModel.transform(input: makeInput(usernameEvents: [
            .next(10, "apple"),
            .next(500, "microsoft"),
            .next(900, "")
        ]))

        let observer = scheduler.createObserver(SearchViewModel.ViewState.self)

        output.viewState
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(
            observer.events.compactMap { $0.value.element },
            [.loading, .results(service.stubbedPage.repos), .loading, .results(service.stubbedPage.repos), .prompt(L10n.Search.promptMessage)]
        )
    }

    func test_viewState_emitsFailure_andErrorMessage_whenFetchFails() {
        let service = GitHubServiceMock()
        service.stubbedError = GitHubServiceError.userNotFound

        let viewModel = makeViewModel(service: service)
        let output = viewModel.transform(input: makeInput(usernameEvents: [
            .next(10, "ghost-user")
        ]))

        let stateObserver = scheduler.createObserver(SearchViewModel.ViewState.self)
        let errorObserver = scheduler.createObserver(String.self)

        output.viewState
            .subscribe(stateObserver)
            .disposed(by: disposeBag)

        output.errorMessage
            .subscribe(errorObserver)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(stateObserver.events.compactMap { $0.value.element }, [.loading, .failure])
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

        output.repos
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(observer.events.compactMap { $0.value.element }, [[], repos, []])
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
            loadNextPage: .empty()
        )
    }
}
