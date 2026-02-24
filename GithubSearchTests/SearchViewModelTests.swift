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
        let viewModel = SearchViewModel(service: service)

        let username = scheduler.createHotObservable([
            .next(10, ""),
            .next(20, "   "),
            .next(30, "apple"),
            .next(40, " apple "),
            .next(50, "")
        ]).asObservable()

        let searchTap: Observable<Void> = scheduler
            .createHotObservable([Recorded<Event<Void>>]())
            .asObservable()

        let selectedRepo: Observable<Repo> = scheduler
            .createHotObservable([Recorded<Event<Repo>>]())
            .asObservable()

        let input = SearchViewModel.Input(username: username, searchTap: searchTap, selectedRepo: selectedRepo)
        let output = viewModel.transform(input: input)

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

    func test_searchTap_fetchesRepos_onlyWhenLatestUsernameAfterTrimIsNonEmpty() {
        // given
        let service = GitHubServiceMock()
        service.stubbedRepos = [Repo.mock(name: "A")]

        let viewModel = SearchViewModel(service: service)

        let username = scheduler.createHotObservable([
            .next(10, "   "),   // empty after trim
            .next(20, "apple"),
            .next(30, "")       // empty
        ]).asObservable()

        let searchTap: Observable<Void> = scheduler.createHotObservable([
            .next(15, ()), // should NOT fetch
            .next(25, ()), // should fetch ("apple")
            .next(35, ())  // should NOT fetch
        ]).asObservable()

        let selectedRepo: Observable<Repo> = scheduler
            .createHotObservable([Recorded<Event<Repo>>]())
            .asObservable()

        let input = SearchViewModel.Input(username: username, searchTap: searchTap, selectedRepo: selectedRepo)
        let output = viewModel.transform(input: input)

        output.repos
            .subscribe()
            .disposed(by: disposeBag)

        // when
        scheduler.start()

        // then
        XCTAssertEqual(service.fetchReposCallCount, 1)
        XCTAssertEqual(service.lastUsername, "apple")
    }

    func test_repos_emitsStubbedRepos_onSuccessfulFetch() {
        // given
        let service = GitHubServiceMock()
        let repos = [Repo.mock(name: "Repo1"), Repo.mock(name: "Repo2")]
        service.stubbedRepos = repos

        let viewModel = SearchViewModel(service: service)

        let username = scheduler.createHotObservable([
            .next(10, "apple")
        ]).asObservable()

        let searchTap: Observable<Void> = scheduler.createHotObservable([
            .next(20, ())
        ]).asObservable()

        let selectedRepo: Observable<Repo> = scheduler
            .createHotObservable([Recorded<Event<Repo>>]())
            .asObservable()

        let input = SearchViewModel.Input(username: username, searchTap: searchTap, selectedRepo: selectedRepo)
        let output = viewModel.transform(input: input)

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

    func test_errorMessage_emitsMappedText_andReposEmitsEmptyArray_onFailure() {
        // given
        let service = GitHubServiceMock()
        service.stubbedError = .http(404)

        let viewModel = SearchViewModel(service: service)

        let username = scheduler.createHotObservable([
            .next(10, "apple")
        ]).asObservable()

        let searchTap: Observable<Void> = scheduler.createHotObservable([
            .next(20, ())
        ]).asObservable()

        let selectedRepo: Observable<Repo> = scheduler
            .createHotObservable([Recorded<Event<Repo>>]())
            .asObservable()

        let input = SearchViewModel.Input(username: username, searchTap: searchTap, selectedRepo: selectedRepo)
        let output = viewModel.transform(input: input)

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
        XCTAssertTrue(errors.contains(where: { $0.contains("HTTP error: 404") }))

        let lastRepos = reposObserver.events.compactMap { $0.value.element }.last
        XCTAssertEqual(lastRepos, [])
    }

    func test_openRepoDetails_forwardsSelectedRepo() {
        // given
        let service = GitHubServiceMock()
        let viewModel = SearchViewModel(service: service)

        let username = scheduler.createHotObservable([
            .next(10, "apple")
        ]).asObservable()

        let searchTap: Observable<Void> = scheduler
            .createHotObservable([Recorded<Event<Void>>]())
            .asObservable()

        let selected = Repo.mock(name: "ChosenRepo")

        let selectedRepo: Observable<Repo> = scheduler.createHotObservable([
            .next(30, selected)
        ]).asObservable()

        let input = SearchViewModel.Input(username: username, searchTap: searchTap, selectedRepo: selectedRepo)
        let output = viewModel.transform(input: input)

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

    func test_emptyMessage_startsWithHint_thenEmitsNoResultsWhenReposEmpty() {
        // given
        let service = GitHubServiceMock()
        service.stubbedRepos = []
        let viewModel = SearchViewModel(service: service)

        let username = scheduler.createHotObservable([
            .next(10, "apple")
        ]).asObservable()

        let searchTap: Observable<Void> = scheduler.createHotObservable([
            .next(20, ())
        ]).asObservable()

        let selectedRepo: Observable<Repo> = scheduler
            .createHotObservable([Recorded<Event<Repo>>]())
            .asObservable()

        let input = SearchViewModel.Input(username: username, searchTap: searchTap, selectedRepo: selectedRepo)
        let output = viewModel.transform(input: input)

        let observer = scheduler.createObserver(String?.self)

        // when
        output.emptyMessage
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        // then
        let values = observer.events.compactMap { $0.value.element }
        XCTAssertTrue(values.contains("Type a username and search."))
        XCTAssertTrue(values.contains("No repositories found."))
    }
}
