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

    func test_loadNextPage_appendsResults() {
        let service = GitHubServiceMock()
        let firstPageRepos = [Repo.mock(id: 1, name: "Repo1")]
        let secondPageRepos = [Repo.mock(id: 2, name: "Repo2")]
        let viewModel = makeViewModel(service: service)

        service.fetchReposHandler = { _, page, _, _ in
            switch page {
            case 1:
                return .just(RepoPage(repos: firstPageRepos, hasNextPage: true))
            case 2:
                return .just(RepoPage(repos: secondPageRepos, hasNextPage: false))
            default:
                return .just(RepoPage(repos: [], hasNextPage: false))
            }
        }

        let output = viewModel.transform(input: makeInput(
            usernameEvents: [.next(10, "apple")],
            loadNextPageEvents: [.next(700, ())]
        ))
        let observer = scheduler.createObserver([Repo].self)

        output.state
            .asObservable()
            .map(\.repos)
            .distinctUntilChanged()
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
        let viewModel = makeViewModel(service: service)

        service.fetchReposHandler = { username, page, _, _ in
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

        let output = viewModel.transform(input: makeInput(
            usernameEvents: [
                .next(10, "apple"),
                .next(900, "microsoft")
            ],
            loadNextPageEvents: [.next(700, ())]
        ))
        let observer = scheduler.createObserver([Repo].self)

        output.state
            .asObservable()
            .map(\.repos)
            .distinctUntilChanged()
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
        let viewModel = makeViewModel(service: service)
        let scheduler = self.scheduler!

        service.fetchReposHandler = { _, page, _, _ in
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

        let output = viewModel.transform(input: makeInput(
            usernameEvents: [.next(10, "apple")],
            loadNextPageEvents: [
                .next(700, ()),
                .next(720, ())
            ]
        ))
        let observer = scheduler.createObserver([Repo].self)

        output.state
            .asObservable()
            .map(\.repos)
            .distinctUntilChanged()
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(service.requestedPages, [1, 2])
        XCTAssertEqual(observer.events.compactMap { $0.value.element }, [[], firstPageRepos, firstPageRepos + secondPageRepos])
    }

    func test_loadNextPage_doesNotFetchWhenNoMorePagesRemain() {
        let service = GitHubServiceMock()
        let repos = [Repo.mock(id: 1, name: "Repo1")]
        let viewModel = makeViewModel(service: service)
        service.stubbedPage = RepoPage(repos: repos, hasNextPage: false)

        let output = viewModel.transform(input: makeInput(
            usernameEvents: [.next(10, "apple")],
            loadNextPageEvents: [.next(700, ())]
        ))
        let observer = scheduler.createObserver([Repo].self)

        output.state
            .asObservable()
            .map(\.repos)
            .distinctUntilChanged()
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(service.requestedPages, [1])
        XCTAssertEqual(observer.events.compactMap { $0.value.element }, [[], repos])
    }

    func test_nextPageFailure_keepsExistingResults_andEmitsErrorMessage() {
        let service = GitHubServiceMock()
        let firstPageRepos = [Repo.mock(id: 1, name: "Repo1")]
        let viewModel = makeViewModel(service: service)

        service.fetchReposHandler = { _, page, _, _ in
            switch page {
            case 1:
                return .just(RepoPage(repos: firstPageRepos, hasNextPage: true))
            case 2:
                return .error(GitHubServiceError.rateLimited)
            default:
                return .just(RepoPage(repos: [], hasNextPage: false))
            }
        }

        let output = viewModel.transform(input: makeInput(
            usernameEvents: [.next(10, "apple")],
            loadNextPageEvents: [.next(700, ())]
        ))
        let reposObserver = scheduler.createObserver([Repo].self)
        let errorObserver = scheduler.createObserver(String.self)
        let stateObserver = scheduler.createObserver(SearchViewModel.SearchPhase.self)

        output.state
            .asObservable()
            .map(\.repos)
            .distinctUntilChanged()
            .subscribe(reposObserver)
            .disposed(by: disposeBag)

        output.alertMessage
            .asObservable()
            .subscribe(errorObserver)
            .disposed(by: disposeBag)

        output.state
            .asObservable()
            .map(\.phase)
            .distinctUntilChanged()
            .subscribe(stateObserver)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(service.requestedPages, [1, 2])
        XCTAssertEqual(reposObserver.events.compactMap { $0.value.element }, [[], firstPageRepos])
        XCTAssertEqual(errorObserver.events.compactMap { $0.value.element }, [L10n.GitHubServiceError.rateLimited])
        XCTAssertEqual(stateObserver.events.compactMap { $0.value.element }, [.prompt(L10n.Search.promptMessage), .loading, .results])
    }

    func test_sortChange_resetsResultsAndRestartsFromPageOne() {
        let service = GitHubServiceMock()
        let bestMatchRepos = [Repo.mock(id: 1, name: "BestMatchRepo")]
        let starsRepos = [Repo.mock(id: 2, name: "StarsRepo")]
        let viewModel = makeViewModel(service: service)

        service.fetchReposHandler = { _, _, _, sort in
            switch sort {
            case .bestMatch:
                return .just(RepoPage(repos: bestMatchRepos, hasNextPage: true))
            case .stars:
                return .just(RepoPage(repos: starsRepos, hasNextPage: false))
            case .updated, .name:
                return .just(RepoPage(repos: [], hasNextPage: false))
            }
        }

        let output = viewModel.transform(input: makeInput(
            usernameEvents: [.next(10, "apple")],
            sortChangedEvents: [.next(700, .stars)]
        ))
        let observer = scheduler.createObserver([Repo].self)

        output.state
            .asObservable()
            .map(\.repos)
            .distinctUntilChanged()
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(service.requestedPages, [1, 1])
        XCTAssertEqual(service.requestedSorts, [.bestMatch, .stars])
        XCTAssertEqual(observer.events.compactMap { $0.value.element }, [[], bestMatchRepos, [], starsRepos])
    }

    func test_loadNextPage_usesSelectedSort() {
        let service = GitHubServiceMock()
        let firstPageRepos = [Repo.mock(id: 1, name: "Repo1")]
        let secondPageRepos = [Repo.mock(id: 2, name: "Repo2")]
        let viewModel = makeViewModel(service: service)

        service.fetchReposHandler = { _, page, _, _ in
            switch page {
            case 1:
                return .just(RepoPage(repos: firstPageRepos, hasNextPage: true))
            case 2:
                return .just(RepoPage(repos: secondPageRepos, hasNextPage: false))
            default:
                return .just(RepoPage(repos: [], hasNextPage: false))
            }
        }

        let output = viewModel.transform(input: makeInput(
            usernameEvents: [.next(10, "apple")],
            sortChangedEvents: [.next(20, .stars)],
            loadNextPageEvents: [.next(900, ())]
        ))

        output.state
            .asObservable()
            .subscribe()
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(service.requestedPages, [1, 1, 2])
        XCTAssertEqual(service.requestedSorts, [.bestMatch, .stars, .stars])
    }

    func test_staleResponseForPreviousSortDoesNotReplaceCurrentResults() {
        let service = GitHubServiceMock()
        let bestMatchRepos = [Repo.mock(id: 1, name: "BestMatchRepo")]
        let starsRepos = [Repo.mock(id: 2, name: "StarsRepo")]
        let viewModel = makeViewModel(service: service)
        let scheduler = self.scheduler!

        service.fetchReposHandler = { _, _, _, sort in
            switch sort {
            case .bestMatch:
                return scheduler.createColdObservable([
                    .next(1_000, RepoPage(repos: bestMatchRepos, hasNextPage: false)),
                    .completed(1_000)
                ]).asSingle()
            case .stars:
                return scheduler.createColdObservable([
                    .next(10, RepoPage(repos: starsRepos, hasNextPage: false)),
                    .completed(10)
                ]).asSingle()
            case .updated, .name:
                return .just(RepoPage(repos: [], hasNextPage: false))
            }
        }

        let output = viewModel.transform(input: makeInput(
            usernameEvents: [.next(10, "apple")],
            sortChangedEvents: [.next(500, .stars)]
        ))
        let observer = scheduler.createObserver([Repo].self)

        output.state
            .asObservable()
            .map(\.repos)
            .distinctUntilChanged()
            .subscribe(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(observer.events.compactMap { $0.value.element }, [[], starsRepos])
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
        sortChangedEvents: [Recorded<Event<SearchSort>>] = [],
        loadNextPageEvents: [Recorded<Event<Void>>] = []
    ) -> SearchViewModel.Input {
        let username = scheduler.createHotObservable(usernameEvents).asObservable()
        let sortChanged = scheduler.createHotObservable(sortChangedEvents).asObservable()
        let loadNextPage = scheduler.createHotObservable(loadNextPageEvents).asObservable()

        return .init(
            username: username,
            sortChanged: sortChanged,
            loadNextPage: loadNextPage
        )
    }
}
