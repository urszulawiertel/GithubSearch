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
            language: "\n",
            owner: .init(login: " \n ", avatarUrl: URL(string: "https://avatars.githubusercontent.com/u/1?v=4"))
        )
        let viewModel = RepoDetailsViewModel(repo: repo, service: GitHubServiceMock())

        let output = viewModel.transform(input: makeInput(
            openOnGitHubTapped: scheduler.createHotObservable([Recorded<Event<Void>>]())
                .asSignal(onErrorSignalWith: .empty())
        ))

        let observer = scheduler.createObserver(RepoDetailsViewModel.State.self)

        output.state
            .drive(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        let state = try XCTUnwrap(observer.events.compactMap(\.value.element).last)
        XCTAssertEqual(state.title, L10n.RepoDetails.titleFallback)
        XCTAssertEqual(state.subtitle, L10n.RepoDetails.subtitleFallback)
        XCTAssertTrue(state.subtitleIsSecondary)
        XCTAssertNotNil(state.avatarURL)
        XCTAssertEqual(state.avatarAccessibilityLabel, L10n.RepoDetails.avatarAccessibilityFallback)
        XCTAssertEqual(state.descriptionText, L10n.RepoDetails.descriptionFallback)
        XCTAssertTrue(state.descriptionIsSecondary)
        XCTAssertEqual(state.languageText, L10n.RepoDetails.languageFallback)
        XCTAssertTrue(state.languageIsSecondary)
        XCTAssertEqual(state.starsText, L10n.RepoDetails.noStarsFallback)
        XCTAssertTrue(state.starsIsSecondary)
        XCTAssertEqual(state.openButtonTitle, L10n.RepoDetails.openButtonTitle)
    }

    func test_state_formatsNonEmptyValuesAndStarCount() throws {
        let updatedAt = GitHubDateParser.date(from: "2026-04-03T12:30:00Z")
        let repo = Repo.mock(
            name: "GithubSearch",
            fullName: "urszula/GithubSearch",
            description: " Search repositories by user. ",
            stargazersCount: 1200,
            forksCount: 12,
            openIssuesCount: 3,
            watchersCount: 44,
            language: " Swift ",
            updatedAt: updatedAt,
            topics: ["ios", " swift ", ""],
            defaultBranch: "main",
            license: RepoLicense(name: "MIT License", spdxId: "MIT"),
            owner: .init(login: "urszula", avatarUrl: URL(string: "https://avatars.githubusercontent.com/u/1?v=4"))
        )
        let viewModel = RepoDetailsViewModel(
            repo: repo,
            service: GitHubServiceMock(),
            currentDate: { GitHubDateParser.date(from: "2026-04-06T12:30:00Z")! }
        )

        let output = viewModel.transform(input: makeInput(
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
        XCTAssertEqual(state.avatarAccessibilityLabel, L10n.RepoDetails.avatarAccessibilityLabel(login: "urszula"))
        XCTAssertEqual(state.descriptionText, "Search repositories by user.")
        XCTAssertFalse(state.descriptionIsSecondary)
        XCTAssertEqual(state.languageText, "Swift")
        XCTAssertFalse(state.languageIsSecondary)
        XCTAssertEqual(state.starsText, "★ 1.200")
        XCTAssertFalse(state.starsIsSecondary)
        XCTAssertEqual(state.forksText, "12")
        XCTAssertEqual(state.openIssuesText, "3")
        XCTAssertEqual(state.watchersText, "44")
        XCTAssertEqual(state.updatedText, L10n.RepoDetails.updatedDaysAgo(3))
        XCTAssertEqual(state.updatedAccessibilityLabel, "\(L10n.RepoDetails.updatedDaysAgo(3)), \(Self.formatDate(updatedAt)!)")
        XCTAssertFalse(state.updatedIsSecondary)
        XCTAssertEqual(state.defaultBranchText, "main")
        XCTAssertFalse(state.defaultBranchIsSecondary)
        XCTAssertEqual(state.licenseText, "MIT License")
        XCTAssertFalse(state.licenseIsSecondary)
        XCTAssertEqual(state.topics, ["ios", "swift"])
    }

    func test_state_loadsDetailSectionsFromService() throws {
        let repo = Repo.mock(name: "Repo", fullName: "owner/Repo")
        let service = GitHubServiceMock()
        service.fetchLanguagesHandler = { owner, repo, forceRefresh in
            XCTAssertEqual(owner, "owner")
            XCTAssertEqual(repo, "Repo")
            XCTAssertFalse(forceRefresh)
            return .just([
                RepositoryLanguage(name: "Swift", bytes: 75, percentage: 75),
                RepositoryLanguage(name: "Ruby", bytes: 25, percentage: 25)
            ])
        }
        service.fetchReadmeHandler = { _, _, forceRefresh in
            XCTAssertFalse(forceRefresh)
            return .just(RepositoryReadme(text: """
            # GithubSearch

            Search repositories by user.

            Built with UIKit.

            Extra paragraph that should not appear.
            """))
        }
        service.fetchLatestReleaseHandler = { _, _ in
            .just(RepositoryRelease(
                name: "Version 1.0",
                tagName: "v1.0",
                publishedAt: GitHubDateParser.date(from: "2026-04-05T10:00:00Z"),
                body: "Initial release notes."
            ))
        }
        let viewModel = RepoDetailsViewModel(repo: repo, service: service)

        let output = viewModel.transform(input: makeInput(
            openOnGitHubTapped: scheduler.createHotObservable([Recorded<Event<Void>>]())
                .asSignal(onErrorSignalWith: .empty())
        ))

        let observer = scheduler.createObserver(RepoDetailsViewModel.State.self)
        output.state
            .drive(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        let state = try XCTUnwrap(observer.events.compactMap(\.value.element).last)
        XCTAssertEqual(state.languagesSection.rows.map(\.name), ["Swift", "Ruby"])
        XCTAssertEqual(state.languagesSection.rows.map(\.percentageText), [
            Self.formatPercentage(75),
            Self.formatPercentage(25)
        ])
        XCTAssertEqual(state.readmeSection.previewText, "GithubSearch\n\nSearch repositories by user.\n\nBuilt with UIKit.")
        XCTAssertEqual(state.releaseSection.titleText, "Version 1.0 (v1.0)")
        XCTAssertEqual(state.releaseSection.publishedText, Self.formatDate(GitHubDateParser.date(from: "2026-04-05T10:00:00Z")))
        XCTAssertEqual(state.releaseSection.notesPreviewText, "Initial release notes.")
    }

    func test_refresh_bypassesCachedSections() {
        let repo = Repo.mock(name: "Repo", fullName: "owner/Repo")
        let service = GitHubServiceMock()
        let loadDetails = scheduler.createHotObservable([
            .next(5, false),
            .next(10, true)
        ]).asSignal(onErrorSignalWith: .empty())
        let viewModel = RepoDetailsViewModel(repo: repo, service: service)

        let output = viewModel.transform(input: makeInput(loadDetails: loadDetails))
        output.state
            .drive()
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(service.requestedLanguageForceRefreshValues, [false, true])
        XCTAssertEqual(service.requestedReadmeForceRefreshValues, [false, true])
    }

    func test_topicSelected_emitsSelectedTopic() {
        let repo = Repo.mock()
        let topicSignal = scheduler.createHotObservable([
            .next(10, "swift"),
            .next(20, "ios")
        ]).asSignal(onErrorSignalWith: .empty())
        let viewModel = RepoDetailsViewModel(repo: repo, service: GitHubServiceMock())
        let output = viewModel.transform(input: makeInput(topicSelected: topicSignal))
        let observer = scheduler.createObserver(String.self)

        output.topicSelected
            .emit(to: observer)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(observer.events.compactMap(\.value.element), ["swift", "ios"])
    }

    func test_relativeUpdatedText_formatsDaysMonthsAndYears() {
        let calendar = Calendar(identifier: .gregorian)
        let now = GitHubDateParser.date(from: "2026-07-06T12:00:00Z")!

        XCTAssertEqual(
            RepoDetailsDateFormatter.relativeUpdatedText(
                from: GitHubDateParser.date(from: "2026-07-06T08:00:00Z"),
                now: now,
                calendar: calendar
            ),
            L10n.RepoDetails.updatedToday
        )
        XCTAssertEqual(
            RepoDetailsDateFormatter.relativeUpdatedText(
                from: GitHubDateParser.date(from: "2026-07-03T12:00:00Z"),
                now: now,
                calendar: calendar
            ),
            L10n.RepoDetails.updatedDaysAgo(3)
        )
        XCTAssertEqual(
            RepoDetailsDateFormatter.relativeUpdatedText(
                from: GitHubDateParser.date(from: "2026-05-06T12:00:00Z"),
                now: now,
                calendar: calendar
            ),
            L10n.RepoDetails.updatedMonthsAgo(2)
        )
        XCTAssertEqual(
            RepoDetailsDateFormatter.relativeUpdatedText(
                from: GitHubDateParser.date(from: "2024-07-06T12:00:00Z"),
                now: now,
                calendar: calendar
            ),
            L10n.RepoDetails.updatedYearsAgo(2)
        )
    }

    func test_readmePreview_cleansMarkdownAndTruncates() {
        let preview = RepoDetailsReadmeFormatter.preview(from: """
        # Title

        **First** paragraph.

        > Quoted paragraph.

        `Code` paragraph.

        Fourth paragraph.
        """, paragraphLimit: 3, characterLimit: 80)

        XCTAssertEqual(preview, "Title\n\nFirst** paragraph.\n\nQuoted paragraph.")
    }

    func test_visibleLanguages_hidesZeroPercentRows() {
        let languages = RepoDetailsLanguageFormatter.visibleLanguages(from: [
            RepositoryLanguage(name: "Swift", bytes: 100, percentage: 99.9),
            RepositoryLanguage(name: "Shell", bytes: 1, percentage: 0),
            RepositoryLanguage(name: "Ruby", bytes: 1, percentage: 0.1)
        ])

        XCTAssertEqual(languages.map(\.name), ["Swift", "Ruby"])
    }

    func test_languagePercentageText_formatsSubOnePercentAsLessThanOnePercent() {
        XCTAssertEqual(RepoDetailsLanguageFormatter.percentageText(0.01), "<1%")
        XCTAssertEqual(RepoDetailsLanguageFormatter.percentageText(0.49), "<1%")
        XCTAssertEqual(RepoDetailsLanguageFormatter.percentageText(0.99), "<1%")
    }

    func test_languagePercentageText_roundsPercentagesAtOrAboveOnePercent() {
        XCTAssertEqual(RepoDetailsLanguageFormatter.percentageText(1), "1%")
        XCTAssertEqual(RepoDetailsLanguageFormatter.percentageText(1.49), "1%")
        XCTAssertEqual(RepoDetailsLanguageFormatter.percentageText(1.5), "2%")
        XCTAssertEqual(RepoDetailsLanguageFormatter.percentageText(75.4), "75%")
        XCTAssertEqual(RepoDetailsLanguageFormatter.percentageText(99.9), "100%")
    }

    func test_state_usesEmptySectionMessagesWhenDetailsAreUnavailable() throws {
        let repo = Repo.mock()
        let viewModel = RepoDetailsViewModel(repo: repo, service: GitHubServiceMock())

        let output = viewModel.transform(input: makeInput(
            openOnGitHubTapped: scheduler.createHotObservable([Recorded<Event<Void>>]())
                .asSignal(onErrorSignalWith: .empty())
        ))

        let observer = scheduler.createObserver(RepoDetailsViewModel.State.self)
        output.state
            .drive(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        let state = try XCTUnwrap(observer.events.compactMap(\.value.element).last)
        XCTAssertEqual(state.languagesSection.message, L10n.RepoDetails.languagesEmptyMessage)
        XCTAssertEqual(state.readmeSection.message, L10n.RepoDetails.readmeEmptyMessage)
        XCTAssertEqual(state.releaseSection.message, L10n.RepoDetails.releaseEmptyMessage)
    }

    func test_openRepoURL_emitsRepoURLWhenButtonTapped() {
        let repoURL = URL(string: "https://github.com/owner/repo")!
        let repo = Repo.mock(htmlUrl: repoURL)
        let viewModel = RepoDetailsViewModel(repo: repo, service: GitHubServiceMock())
        let tapSignal = scheduler.createHotObservable([
            .next(10, ()),
            .next(20, ())
        ]).asSignal(onErrorSignalWith: .empty())

        let output = viewModel.transform(input: makeInput(openOnGitHubTapped: tapSignal))
        let observer = scheduler.createObserver(URL.self)

        output.openRepoURL
            .emit(to: observer)
            .disposed(by: disposeBag)

        scheduler.start()

        let emittedURLs = observer.events.compactMap(\.value.element)
        XCTAssertEqual(emittedURLs, [repoURL, repoURL])
    }

    func test_state_exposesNilAvatarURLWhenOwnerAvatarIsUnavailable() throws {
        let repo = Repo.mock(owner: .init(login: "owner", avatarUrl: nil))
        let viewModel = RepoDetailsViewModel(repo: repo, service: GitHubServiceMock())

        let output = viewModel.transform(input: makeInput(
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
        XCTAssertEqual(state.avatarAccessibilityLabel, L10n.RepoDetails.avatarAccessibilityLabel(login: "owner"))
    }

    func test_state_usesFallbackAvatarLabelWhenOwnerLoginIsBlank() throws {
        let repo = Repo.mock(owner: .init(login: " \n ", avatarUrl: URL(string: "https://avatars.githubusercontent.com/u/1?v=4")))
        let viewModel = RepoDetailsViewModel(repo: repo, service: GitHubServiceMock())

        let output = viewModel.transform(input: makeInput(
            openOnGitHubTapped: scheduler.createHotObservable([Recorded<Event<Void>>]())
                .asSignal(onErrorSignalWith: .empty())
        ))

        let observer = scheduler.createObserver(RepoDetailsViewModel.State.self)

        output.state
            .drive(observer)
            .disposed(by: disposeBag)

        scheduler.start()

        let state = try XCTUnwrap(observer.events.compactMap(\.value.element).last)
        XCTAssertEqual(state.avatarAccessibilityLabel, L10n.RepoDetails.avatarAccessibilityFallback)
    }

    private static func formatDate(_ date: Date?) -> String? {
        guard let date else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private static func formatPercentage(_ percentage: Double) -> String {
        RepoDetailsLanguageFormatter.percentageText(percentage)
    }

    private func makeInput(
        openOnGitHubTapped: Signal<Void> = .empty(),
        loadDetails: Signal<Bool> = .just(false),
        topicSelected: Signal<String> = .empty()
    ) -> RepoDetailsViewModel.Input {
        RepoDetailsViewModel.Input(
            openOnGitHubTapped: openOnGitHubTapped,
            loadDetails: loadDetails,
            topicSelected: topicSelected
        )
    }
}
