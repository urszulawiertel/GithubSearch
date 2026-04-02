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
        service.stubbedRepos = repos

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

        let values = observer.events.compactMap { $0.value.element }
        XCTAssertEqual(values, [[], repos, [], repos])
    }

    func test_isLoading_startsImmediately_forNonEmptyQueryChanges() {
        let service = GitHubServiceMock()
        service.stubbedRepos = [Repo.mock(name: "Repo1")]

        let viewModel = makeViewModel(service: service)
        let output = viewModel.transform(input: makeInput(usernameEvents: [
            .next(10, "apple"),
            .next(500, "microsoft"),
            .next(900, "")
        ]))

        let observer = scheduler.createObserver(Bool.self)

        output.isLoading
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        let values = observer.events.compactMap { $0.value.element }
        XCTAssertEqual(values, [true, false, true, false])
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
        let selectedRepo: Observable<Repo> = scheduler
            .createHotObservable([Recorded<Event<Repo>>]())
            .asObservable()

        return .init(username: username, selectedRepo: selectedRepo)
    }
}
