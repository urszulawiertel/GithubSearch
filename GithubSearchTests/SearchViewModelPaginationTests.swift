//
//  SearchViewModelPaginationTests.swift
//  GithubSearchTests
//
//  Created by Codex on 06/04/2026.
//

import XCTest
import RxSwift
import RxTest
@testable import GithubSearch

final class SearchViewModelPaginationTests: XCTestCase {

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

    func test_firstPageLoad_fetchesPageOne_andEmitsResults() {
        let service = GitHubServiceMock()
        let repos = [Repo.mock(name: "Repo1"), Repo.mock(name: "Repo2")]
        service.stubbedPage = RepoPage(repos: repos, hasNextPage: true)

        let output = makeViewModel(service: service).transform(input: makeInput(usernameEvents: [
            .next(10, "apple")
        ]))
        let observer = scheduler.createObserver([Repo].self)

        output.repos
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(service.requestedPages, [1])
        XCTAssertEqual(observer.events.compactMap { $0.value.element }, [[], repos])
    }

    func test_loadNextPage_appendsResults() {
        let service = GitHubServiceMock()
        let firstPageRepos = [Repo.mock(id: 1, name: "Repo1")]
        let secondPageRepos = [Repo.mock(id: 2, name: "Repo2")]
        service.fetchReposHandler = { _, page, _ in
            switch page {
            case 1:
                return .just(RepoPage(repos: firstPageRepos, hasNextPage: true))
            case 2:
                return .just(RepoPage(repos: secondPageRepos, hasNextPage: false))
            default:
                return .just(RepoPage(repos: [], hasNextPage: false))
            }
        }

        let output = makeViewModel(service: service).transform(input: makeInput(
            usernameEvents: [.next(10, "apple")],
            loadNextPageEvents: [.next(500, ())]
        ))
        let observer = scheduler.createObserver([Repo].self)

        output.repos
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(service.requestedPages, [1, 2])
        XCTAssertEqual(observer.events.compactMap { $0.value.element }, [[], firstPageRepos, firstPageRepos + secondPageRepos])
    }

    func test_resetOnNewQuery_clearsResultsAndRestartsFromPageOne() {
        let service = GitHubServiceMock()
        let appleRepos = [Repo.mock(id: 1, name: "AppleRepo")]
        let appleSecondPageRepos = [Repo.mock(id: 2, name: "AppleRepo2")]
        let microsoftRepos = [Repo.mock(id: 3, name: "MicrosoftRepo")]
        service.fetchReposHandler = { username, page, _ in
            switch (username, page) {
            case ("apple", 1):
                return .just(RepoPage(repos: appleRepos, hasNextPage: true))
            case ("apple", 2):
                return .just(RepoPage(repos: appleSecondPageRepos, hasNextPage: false))
            case ("microsoft", 1):
                return .just(RepoPage(repos: microsoftRepos, hasNextPage: false))
            default:
                return .just(RepoPage(repos: [], hasNextPage: false))
            }
        }

        let output = makeViewModel(service: service).transform(input: makeInput(
            usernameEvents: [
                .next(10, "apple"),
                .next(800, "microsoft")
            ],
            loadNextPageEvents: [.next(500, ())]
        ))
        let observer = scheduler.createObserver([Repo].self)

        output.repos
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(service.requestedPages, [1, 2, 1])
        XCTAssertEqual(observer.events.compactMap { $0.value.element }, [
            [],
            appleRepos,
            appleRepos + appleSecondPageRepos,
            [],
            microsoftRepos
        ])
    }

    func test_loadNextPage_doesNotDuplicateWhileRequestIsInProgress() {
        let service = GitHubServiceMock()
        let firstPageRepos = [Repo.mock(id: 1, name: "Repo1")]
        let secondPageRepos = [Repo.mock(id: 2, name: "Repo2")]
        service.fetchReposHandler = { [scheduler] _, page, _ in
            switch page {
            case 1:
                return scheduler.createColdObservable([
                    .next(10, RepoPage(repos: firstPageRepos, hasNextPage: true)),
                    .completed(10)
                ]).asSingle()
            case 2:
                return scheduler.createColdObservable([
                    .next(50, RepoPage(repos: secondPageRepos, hasNextPage: false)),
                    .completed(50)
                ]).asSingle()
            default:
                return .just(RepoPage(repos: [], hasNextPage: false))
            }
        }

        let output = makeViewModel(service: service).transform(input: makeInput(
            usernameEvents: [.next(10, "apple")],
            loadNextPageEvents: [
                .next(500, ()),
                .next(520, ())
            ]
        ))
        let observer = scheduler.createObserver([Repo].self)

        output.repos
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(service.requestedPages, [1, 2])
        XCTAssertEqual(observer.events.compactMap { $0.value.element }, [[], firstPageRepos, firstPageRepos + secondPageRepos])
    }

    func test_emptyQuery_clearsResultsAndResetsPaginationState() {
        let service = GitHubServiceMock()
        let repos = [Repo.mock(id: 1, name: "Repo1")]
        service.fetchReposHandler = { _, page, _ in
            switch page {
            case 1:
                return .just(RepoPage(repos: repos, hasNextPage: true))
            case 2:
                return .just(RepoPage(repos: [Repo.mock(id: 2, name: "Repo2")], hasNextPage: false))
            default:
                return .just(RepoPage(repos: [], hasNextPage: false))
            }
        }

        let output = makeViewModel(service: service).transform(input: makeInput(
            usernameEvents: [
                .next(10, "apple"),
                .next(700, "")
            ],
            loadNextPageEvents: [.next(800, ())]
        ))
        let observer = scheduler.createObserver([Repo].self)

        output.repos
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(service.requestedPages, [1])
        XCTAssertEqual(observer.events.compactMap { $0.value.element }, [[], repos, []])
    }

    private func makeViewModel(service: GitHubServiceMock) -> SearchViewModel {
        SearchViewModel(
            service: service,
            scheduler: scheduler,
            debounceInterval: .milliseconds(400)
        )
    }

    private func makeInput(
        usernameEvents: [Recorded<Event<String>>],
        loadNextPageEvents: [Recorded<Event<Void>>] = []
    ) -> SearchViewModel.Input {
        let username = scheduler.createHotObservable(usernameEvents).asObservable()
        let loadNextPage = scheduler.createHotObservable(loadNextPageEvents).asObservable()

        return .init(
            username: username,
            loadNextPage: loadNextPage
        )
    }
}
