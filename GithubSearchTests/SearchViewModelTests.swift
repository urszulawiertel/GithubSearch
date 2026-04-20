//
//  SearchViewModelTests.swift
//  GithubSearchTests
//
//  Created by Ula on 24/02/2026.
//

import XCTest
import RxSwift
import RxCocoa
import RxTest
@testable import GithubSearch

final class SearchViewModelTests: XCTestCase {

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

    func test_debounce_keepsLatestRequestAfterTyping() {
        let service = GitHubServiceMock()
        service.stubbedPage = RepoPage(repos: [Repo.mock(name: "A")], hasNextPage: false)

        let viewModel = SearchViewModel(
            service: service,
            scheduler: scheduler,
            debounceInterval: .seconds(1)
        )

        let username = scheduler.createHotObservable([
            .next(10, "a"),
            .next(11, "ap"),
            .next(12, "app"),
            .next(13, "apple"),
            .next(30, "apple")
        ]).asObservable()

        let output = viewModel.transform(input: makeInput(username: username))

        output.state
            .asObservable()
            .map(\.repos)
            .subscribe()
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(service.fetchReposCallCount, 4)
        XCTAssertEqual(service.lastUsername, "apple")
        XCTAssertEqual(service.lastPage, 1)
    }

    func test_debounce_doesNotFetchForWhitespaceOnly() {
        let service = GitHubServiceMock()
        service.stubbedPage = RepoPage(repos: [Repo.mock(name: "A")], hasNextPage: false)

        let viewModel = SearchViewModel(
            service: service,
            scheduler: scheduler,
            debounceInterval: .milliseconds(400)
        )

        let username = scheduler.createHotObservable([
            .next(10, "   "),
            .next(20, "      ")
        ]).asObservable()

        _ = viewModel.transform(input: makeInput(username: username))

        scheduler.start()

        XCTAssertEqual(service.fetchReposCallCount, 0)
        XCTAssertNil(service.lastUsername)
    }

    func test_repos_emitsStubbedRepos_onSuccessfulFetch() {
        let service = GitHubServiceMock()
        let repos = [Repo.mock(name: "Repo1"), Repo.mock(name: "Repo2")]
        service.stubbedPage = RepoPage(repos: repos, hasNextPage: false)

        let viewModel = SearchViewModel(
            service: service,
            scheduler: scheduler,
            debounceInterval: .milliseconds(400)
        )

        let username = scheduler.createHotObservable([
            .next(10, "apple")
        ]).asObservable()

        let output = viewModel.transform(input: makeInput(username: username))
        let observer = scheduler.createObserver([Repo].self)

        output.state
            .asObservable()
            .map(\.repos)
            .distinctUntilChanged()
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        let last = observer.events.compactMap { $0.value.element }.last
        XCTAssertEqual(last, repos)
    }

    func test_repos_clearsImmediately_whenUsernameBecomesEmptyAfterShowingResults() {
        let service = GitHubServiceMock()
        let repos = [Repo.mock(name: "Repo1"), Repo.mock(name: "Repo2")]
        service.stubbedPage = RepoPage(repos: repos, hasNextPage: false)

        let viewModel = SearchViewModel(
            service: service,
            scheduler: scheduler,
            debounceInterval: .milliseconds(400)
        )

        let username = scheduler.createHotObservable([
            .next(10, "apple"),
            .next(500, "   ")
        ]).asObservable()

        let output = viewModel.transform(input: makeInput(username: username))
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

    func test_phase_resetsToPromptImmediately_whenUsernameBecomesEmpty() {
        let service = GitHubServiceMock()
        service.stubbedPage = RepoPage(repos: [Repo.mock(name: "Repo1")], hasNextPage: false)

        let viewModel = SearchViewModel(
            service: service,
            scheduler: scheduler,
            debounceInterval: .milliseconds(400)
        )

        let username = scheduler.createHotObservable([
            .next(10, "apple"),
            .next(500, "")
        ]).asObservable()

        let output = viewModel.transform(input: makeInput(username: username))
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
            [.prompt(L10n.Search.promptMessage), .loading, .results, .prompt(L10n.Search.promptMessage)]
        )
    }

    func test_alertMessage_emitsMappedText_andReposEmitsEmptyArray_onFailure() {
        let service = GitHubServiceMock()
        service.stubbedError = GitHubServiceError.userNotFound

        let viewModel = SearchViewModel(
            service: service,
            scheduler: scheduler,
            debounceInterval: .milliseconds(400)
        )

        let username = scheduler.createHotObservable([
            .next(10, "apple")
        ]).asObservable()

        let output = viewModel.transform(input: makeInput(username: username))

        let errorObserver = scheduler.createObserver(String.self)
        let reposObserver = scheduler.createObserver([Repo].self)

        output.alertMessage
            .asObservable()
            .subscribe(errorObserver)
            .disposed(by: disposeBag)

        output.state
            .asObservable()
            .map(\.repos)
            .distinctUntilChanged()
            .subscribe(reposObserver)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(errorObserver.events.compactMap { $0.value.element }, [L10n.GitHubServiceError.userNotFound])
        XCTAssertEqual(reposObserver.events.compactMap { $0.value.element }.last, [])
    }

    func test_alertMessage_usesFriendlyMessages_forServiceErrors() {
        XCTAssertEqual(GitHubServiceError.userNotFound.userMessage, L10n.GitHubServiceError.userNotFound)
        XCTAssertEqual(GitHubServiceError.connectivity.userMessage, L10n.GitHubServiceError.connectivity)
        XCTAssertEqual(GitHubServiceError.rateLimited.userMessage, L10n.GitHubServiceError.rateLimited)
        XCTAssertEqual(GitHubServiceError.unknown.userMessage, L10n.Common.genericErrorMessage)
    }

    func test_alertMessage_fallsBackToGenericMessage_forUnknownErrors() {
        struct DummyError: Error {}

        let service = GitHubServiceMock()
        service.stubbedError = DummyError()

        let viewModel = SearchViewModel(
            service: service,
            scheduler: scheduler,
            debounceInterval: .milliseconds(400)
        )

        let username = scheduler.createHotObservable([
            .next(10, "apple")
        ]).asObservable()

        let output = viewModel.transform(input: makeInput(username: username))

        let errorObserver = scheduler.createObserver(String.self)
        let reposObserver = scheduler.createObserver([Repo].self)

        output.alertMessage
            .asObservable()
            .subscribe(errorObserver)
            .disposed(by: disposeBag)

        output.state
            .asObservable()
            .map(\.repos)
            .distinctUntilChanged()
            .subscribe(reposObserver)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(errorObserver.events.compactMap { $0.value.element }, [L10n.Common.genericErrorMessage])
    }

    private func makeInput(
        username: Observable<String>,
        sortChanged: Observable<SearchSort> = .empty(),
        loadNextPage: Observable<Void> = .empty()
    ) -> SearchViewModel.Input {
        .init(
            username: username,
            sortChanged: sortChanged,
            loadNextPage: loadNextPage
        )
    }
}
