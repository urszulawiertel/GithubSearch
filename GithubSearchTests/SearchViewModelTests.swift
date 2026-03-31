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

    func test_isSearchEnabled_emitsFalseForEmptyAndWhitespaceTrueForNonEmpty() {
        // given
        let service = GitHubServiceMock()
        let viewModel = SearchViewModel(
            service: service,
            scheduler: scheduler,
            debounceInterval: .milliseconds(400)
        )

        let username = scheduler.createHotObservable([
            .next(10, ""),
            .next(20, "   "),
            .next(30, "apple"),
            .next(40, " apple "),
            .next(50, "")
        ]).asObservable()

        let selectedRepo: Observable<Repo> = scheduler
            .createHotObservable([Recorded<Event<Repo>>]())
            .asObservable()

        let output = viewModel.transform(input: .init(username: username, selectedRepo: selectedRepo))

        let observer = scheduler.createObserver(Bool.self)

        // when
        output.isSearchEnabled
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        // then
        let values = observer.events.compactMap { $0.value.element }
        XCTAssertEqual(values, [false, true, false])
    }

    func test_debounce_triggersFetchOnlyAfterUserStopsTyping() {
        // given
        let service = GitHubServiceMock()
        service.stubbedRepos = [Repo.mock(name: "A")]

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

        let selectedRepo: Observable<Repo> = scheduler
            .createHotObservable([Recorded<Event<Repo>>]())
            .asObservable()

        let output = viewModel.transform(input: .init(username: username, selectedRepo: selectedRepo))

        // when
        output.repos
            .subscribe()
            .disposed(by: disposeBag)

        scheduler.start()

        // then
        XCTAssertEqual(service.fetchReposCallCount, 1)
        XCTAssertEqual(service.lastUsername, "apple")
    }

    func test_debounce_doesNotFetchForWhitespaceOnly() {
        // given
        let service = GitHubServiceMock()
        service.stubbedRepos = [Repo.mock(name: "A")]

        let viewModel = SearchViewModel(
            service: service,
            scheduler: scheduler,
            debounceInterval: .milliseconds(400)
        )

        let username = scheduler.createHotObservable([
            .next(10, "   "),
            .next(20, "      ")
        ]).asObservable()

        let selectedRepo: Observable<Repo> = scheduler
            .createHotObservable([Recorded<Event<Repo>>]())
            .asObservable()

        // when
        _ = viewModel.transform(input: .init(username: username, selectedRepo: selectedRepo))

        scheduler.start()

        XCTAssertEqual(service.fetchReposCallCount, 0)
        XCTAssertNil(service.lastUsername)
    }

    func test_repos_emitsStubbedRepos_onSuccessfulFetch() {
        // given
        let service = GitHubServiceMock()
        let repos = [Repo.mock(name: "Repo1"), Repo.mock(name: "Repo2")]
        service.stubbedRepos = repos

        let viewModel = SearchViewModel(
            service: service,
            scheduler: scheduler,
            debounceInterval: .milliseconds(400)
        )

        let username = scheduler.createHotObservable([
            .next(10, "apple")
        ]).asObservable()

        let selectedRepo: Observable<Repo> = scheduler
            .createHotObservable([Recorded<Event<Repo>>]())
            .asObservable()

        let output = viewModel.transform(input: .init(username: username, selectedRepo: selectedRepo))

        let observer = scheduler.createObserver([Repo].self)

        // when
        output.repos
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        // then
        let last = observer.events.compactMap { $0.value.element }.last
        XCTAssertEqual(last, repos)
    }

    func test_repos_clearsImmediately_whenUsernameBecomesEmptyAfterShowingResults() {
        // given
        let service = GitHubServiceMock()
        let repos = [Repo.mock(name: "Repo1"), Repo.mock(name: "Repo2")]
        service.stubbedRepos = repos

        let viewModel = SearchViewModel(
            service: service,
            scheduler: scheduler,
            debounceInterval: .milliseconds(400)
        )

        let username = scheduler.createHotObservable([
            .next(10, "apple"),
            .next(500, "   ")
        ]).asObservable()

        let selectedRepo: Observable<Repo> = scheduler
            .createHotObservable([Recorded<Event<Repo>>]())
            .asObservable()

        let output = viewModel.transform(input: .init(username: username, selectedRepo: selectedRepo))

        let observer = scheduler.createObserver([Repo].self)

        // when
        output.repos
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        // then
        let values = observer.events.compactMap { $0.value.element }
        XCTAssertEqual(values, [repos, []])
    }

    func test_emptyMessage_resetsToPromptImmediately_whenUsernameBecomesEmpty() {
        // given
        let service = GitHubServiceMock()
        service.stubbedRepos = [Repo.mock(name: "Repo1")]

        let viewModel = SearchViewModel(
            service: service,
            scheduler: scheduler,
            debounceInterval: .milliseconds(400)
        )

        let username = scheduler.createHotObservable([
            .next(10, "apple"),
            .next(500, "")
        ]).asObservable()

        let selectedRepo: Observable<Repo> = scheduler
            .createHotObservable([Recorded<Event<Repo>>]())
            .asObservable()

        let output = viewModel.transform(input: .init(username: username, selectedRepo: selectedRepo))

        let observer = scheduler.createObserver(String.self)

        // when
        output.emptyMessage
            .map { $0 ?? "<nil>" }
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        // then
        let values = observer.events.compactMap { $0.value.element }
        XCTAssertEqual(values, ["<nil>", "Enter a GitHub username"])
    }

    func test_errorMessage_emitsMappedText_andReposEmitsEmptyArray_onFailure() {
        // given
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

        let selectedRepo: Observable<Repo> = scheduler
            .createHotObservable([Recorded<Event<Repo>>]())
            .asObservable()

        let output = viewModel.transform(input: .init(username: username, selectedRepo: selectedRepo))

        let errorObserver = scheduler.createObserver(String.self)
        let reposObserver = scheduler.createObserver([Repo].self)

        // when
        output.errorMessage
            .subscribe(errorObserver)
            .disposed(by: disposeBag)

        output.repos
            .subscribe(reposObserver)
            .disposed(by: disposeBag)

        scheduler.start()

        // then
        let errors = errorObserver.events.compactMap { $0.value.element }
        XCTAssertEqual(errors, ["We couldn't find that GitHub user."])

        let lastRepos = reposObserver.events.compactMap { $0.value.element }.last
        XCTAssertEqual(lastRepos, [])
    }

    func test_errorMessage_usesFriendlyMessages_forServiceErrors() {
        XCTAssertEqual(GitHubServiceError.userNotFound.userMessage, "We couldn't find that GitHub user.")
        XCTAssertEqual(GitHubServiceError.connectivity.userMessage, "You're offline right now. Check your internet connection and try again.")
        XCTAssertEqual(GitHubServiceError.rateLimited.userMessage, "GitHub is receiving too many requests right now. Please wait a moment and try again.")
        XCTAssertEqual(GitHubServiceError.unknown.userMessage, "Something went wrong. Please try again.")
    }

    func test_errorMessage_fallsBackToGenericMessage_forUnknownErrors() {
        // given
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

        let selectedRepo: Observable<Repo> = scheduler
            .createHotObservable([Recorded<Event<Repo>>]())
            .asObservable()

        let output = viewModel.transform(input: .init(username: username, selectedRepo: selectedRepo))

        let errorObserver = scheduler.createObserver(String.self)
        let reposObserver = scheduler.createObserver([Repo].self)

        // when
        output.errorMessage
            .subscribe(errorObserver)
            .disposed(by: disposeBag)

        output.repos
            .subscribe(reposObserver)
            .disposed(by: disposeBag)

        scheduler.start()

        // then
        let errors = errorObserver.events.compactMap { $0.value.element }
        XCTAssertEqual(errors, ["Something went wrong. Please try again."])
    }

    func test_openRepoDetails_forwardsSelectedRepo() {
        // given
        let service = GitHubServiceMock()
        let viewModel = SearchViewModel(
            service: service,
            scheduler: scheduler,
            debounceInterval: .milliseconds(400)
        )

        let username = scheduler.createHotObservable([
            .next(10, "apple")
        ]).asObservable()

        let selected = Repo.mock(name: "ChosenRepo")

        let selectedRepo: Observable<Repo> = scheduler.createHotObservable([
            .next(30, selected)
        ]).asObservable()

        let output = viewModel.transform(input: .init(username: username, selectedRepo: selectedRepo))

        let observer = scheduler.createObserver(Repo.self)

        // when
        output.openRepoDetails
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        // then
        let values = observer.events.compactMap { $0.value.element }
        XCTAssertEqual(values, [selected])
    }
}
