//
//  RepoDetailsViewModelTests.swift
//  GithubSearchTests
//
//  Created by Codex on 02/04/2026.
//

import XCTest
import RxSwift
import RxCocoa
import RxTest
@testable import GithubSearch

final class RepoDetailsViewModelTests: XCTestCase {

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

    func test_state_formatsFallbacksForMissingOrBlankValues() throws {
        let repo = Repo.mock(
            name: "   ",
            fullName: "",
            description: "  ",
            stargazersCount: 0,
            language: "\n"
        )
        let viewModel = RepoDetailsViewModel(repo: repo)

        let output = viewModel.transform(input: .init(
            openOnGitHubTapped: scheduler.createHotObservable([Recorded<Event<Void>>]())
                .asSignal(onErrorSignalWith: .empty())
        ))

        let observer = scheduler.createObserver(RepoDetailsViewModel.State.self)

        output.state
            .drive(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        let state = try XCTUnwrap(observer.events.compactMap(\.value.element).last)
        XCTAssertEqual(state.title, "Repository")
        XCTAssertEqual(state.subtitle, "Full name unavailable")
        XCTAssertTrue(state.subtitleIsSecondary)
        XCTAssertNotNil(state.avatarURL)
        XCTAssertEqual(state.descriptionText, "No description provided.")
        XCTAssertTrue(state.descriptionIsSecondary)
        XCTAssertEqual(state.languageText, "Not specified")
        XCTAssertTrue(state.languageIsSecondary)
        XCTAssertEqual(state.starsText, "No stars yet")
        XCTAssertTrue(state.starsIsSecondary)
        XCTAssertEqual(state.openButtonTitle, "Open on GitHub")
    }

    func test_state_formatsNonEmptyValuesAndStarCount() throws {
        let repo = Repo.mock(
            name: "GithubSearch",
            fullName: "urszula/GithubSearch",
            description: " Search repositories by user. ",
            stargazersCount: 1200,
            language: " Swift "
        )
        let viewModel = RepoDetailsViewModel(repo: repo)

        let output = viewModel.transform(input: .init(
            openOnGitHubTapped: scheduler.createHotObservable([Recorded<Event<Void>>]())
                .asSignal(onErrorSignalWith: .empty())
        ))

        let observer = scheduler.createObserver(RepoDetailsViewModel.State.self)

        output.state
            .drive(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        let state = try XCTUnwrap(observer.events.compactMap(\.value.element).last)
        XCTAssertEqual(state.title, "GithubSearch")
        XCTAssertEqual(state.subtitle, "urszula/GithubSearch")
        XCTAssertFalse(state.subtitleIsSecondary)
        XCTAssertEqual(state.avatarURL, URL(string: "https://avatars.githubusercontent.com/u/1?v=4"))
        XCTAssertEqual(state.descriptionText, "Search repositories by user.")
        XCTAssertFalse(state.descriptionIsSecondary)
        XCTAssertEqual(state.languageText, "Swift")
        XCTAssertFalse(state.languageIsSecondary)
        XCTAssertEqual(state.starsText, "★ 1.200")
        XCTAssertFalse(state.starsIsSecondary)
    }

    func test_openRepoURL_emitsRepoURLWhenButtonTapped() {
        let repoURL = URL(string: "https://github.com/owner/repo")!
        let repo = Repo.mock(htmlUrl: repoURL)
        let viewModel = RepoDetailsViewModel(repo: repo)
        let tapSignal = scheduler.createHotObservable([
            .next(10, ()),
            .next(20, ())
        ]).asSignal(onErrorSignalWith: .empty())

        let output = viewModel.transform(input: .init(openOnGitHubTapped: tapSignal))
        let observer = scheduler.createObserver(URL.self)

        output.openRepoURL
            .emit(to: observer)
            .disposed(by: disposeBag)

        scheduler.start()

        let emittedURLs = observer.events.compactMap(\.value.element)
        XCTAssertEqual(emittedURLs, [repoURL, repoURL])
    }

    func test_state_exposesNilAvatarURLWhenOwnerAvatarIsUnavailable() throws {
        let repo = Repo.mock(owner: .init(avatarUrl: nil))
        let viewModel = RepoDetailsViewModel(repo: repo)

        let output = viewModel.transform(input: .init(
            openOnGitHubTapped: scheduler.createHotObservable([Recorded<Event<Void>>]())
                .asSignal(onErrorSignalWith: .empty())
        ))

        let observer = scheduler.createObserver(RepoDetailsViewModel.State.self)

        output.state
            .drive(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        let state = try XCTUnwrap(observer.events.compactMap(\.value.element).last)
        XCTAssertNil(state.avatarURL)
    }
}
