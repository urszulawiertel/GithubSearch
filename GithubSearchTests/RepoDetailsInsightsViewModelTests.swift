//
//  RepoDetailsInsightsViewModelTests.swift
//  GithubSearchTests
//

import XCTest
import RxSwift
import RxCocoa
import RxTest
import RxBlocking
@testable import GithubSearch

final class RepoDetailsInsightsViewModelTests: XCTestCase {
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

    func test_insightsStateIsInitiallyIdleAndDoesNotGenerateAutomatically() {
        let insightsService = RepositoryInsightsServiceMock()
        let viewModel = makeViewModel(insightsService: insightsService)
        let output = viewModel.transform(input: makeInput())
        let observer = scheduler.createObserver(RepoDetailsViewModel.State.self)
        output.state.drive(observer).disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(observer.events.compactMap(\.value.element).last?.insightsSection, .idle)
        XCTAssertTrue(insightsService.requestedContexts.isEmpty)
    }

    func test_generateInsightsEmitsLoadingThenLoaded() {
        let insights = Self.makeInsights(overview: "Generated overview")
        let insightsService = RepositoryInsightsServiceMock()
        insightsService.handler = { _ in .just(insights) }
        let taps = scheduler.createHotObservable([.next(10, ())]).asSignal(onErrorSignalWith: .empty())
        let viewModel = makeViewModel(insightsService: insightsService)
        let output = viewModel.transform(input: makeInput(generateInsightsTapped: taps))
        let observer = scheduler.createObserver(RepoDetailsViewModel.State.self)
        output.state.drive(observer).disposed(by: disposeBag)

        scheduler.start()

        let states = observer.events.compactMap(\.value.element?.insightsSection)
        XCTAssertTrue(states.contains(.loading))
        XCTAssertEqual(states.last, .loaded(insights))
    }

    func test_failureProducesRetryableStateAndRetryStartsNewRequest() {
        let insights = Self.makeInsights(overview: "Retry succeeded")
        let insightsService = RepositoryInsightsServiceMock()
        insightsService.handler = { _ in
            insightsService.requestedContexts.count == 1
                ? .error(RepositoryInsightsServiceError.server)
                : .just(insights)
        }
        let taps = scheduler.createHotObservable([.next(10, ()), .next(20, ())])
            .asSignal(onErrorSignalWith: .empty())
        let viewModel = makeViewModel(insightsService: insightsService)
        let output = viewModel.transform(input: makeInput(generateInsightsTapped: taps))
        let observer = scheduler.createObserver(RepoDetailsViewModel.State.self)
        output.state.drive(observer).disposed(by: disposeBag)

        scheduler.start()

        let states = observer.events.compactMap(\.value.element?.insightsSection)
        XCTAssertTrue(states.contains(.failed))
        XCTAssertEqual(states.last, .loaded(insights))
        XCTAssertEqual(insightsService.requestedContexts.count, 2)
    }

    func test_repeatedTapsWhileLoadingDoNotCreateDuplicateRequests() {
        let pendingResponse = PublishSubject<RepositoryInsights>()
        let insightsService = RepositoryInsightsServiceMock()
        insightsService.handler = { _ in pendingResponse.take(1).asSingle() }
        let taps = scheduler.createHotObservable([.next(10, ()), .next(11, ()), .next(12, ())])
            .asSignal(onErrorSignalWith: .empty())

        let viewModel = makeViewModel(insightsService: insightsService)
        viewModel.transform(input: makeInput(generateInsightsTapped: taps)).state
            .drive()
            .disposed(by: disposeBag)
        scheduler.start()

        XCTAssertEqual(insightsService.requestedContexts.count, 1)
    }

    func test_viewClosedCancelsGenerationAndPreventsLateStateUpdate() {
        var wasCancelled = false
        var observerAfterCancellation: ((RepositoryInsights) -> Void)?
        let insightsService = RepositoryInsightsServiceMock()
        insightsService.handler = { _ in
            Single.create { single in
                observerAfterCancellation = { single(.success($0)) }
                return Disposables.create { wasCancelled = true }
            }
        }
        let taps = scheduler.createHotObservable([.next(10, ())]).asSignal(onErrorSignalWith: .empty())
        let closed = scheduler.createHotObservable([.next(20, ())]).asSignal(onErrorSignalWith: .empty())
        let viewModel = makeViewModel(insightsService: insightsService)
        let output = viewModel.transform(input: makeInput(
            generateInsightsTapped: taps,
            viewClosed: closed
        ))
        let observer = scheduler.createObserver(RepoDetailsViewModel.State.self)
        output.state.drive(observer).disposed(by: disposeBag)
        scheduler.scheduleAt(30) {
            observerAfterCancellation?(Self.makeInsights(overview: "Late response"))
        }

        scheduler.start()

        XCTAssertTrue(wasCancelled)
        XCTAssertFalse(observer.events.compactMap(\.value.element?.insightsSection).contains {
            $0 == .loaded(Self.makeInsights(overview: "Late response"))
        })
    }

    func test_newRepositoryViewModelDoesNotReusePreviousInsights() throws {
        let insightsService = RepositoryInsightsServiceMock()
        insightsService.handler = { context in .just(Self.makeInsights(overview: context.fullName)) }
        let firstViewModel = makeViewModel(
            repo: .mock(name: "First", fullName: "owner/First", description: "First description"),
            insightsService: insightsService
        )
        let secondViewModel = makeViewModel(
            repo: .mock(name: "Second", fullName: "owner/Second", description: "Second description"),
            insightsService: insightsService
        )

        let firstState = try firstViewModel.transform(input: makeInput(generateInsightsTapped: .just(()))).state
            .asObservable().toBlocking().last()
        let secondState = try secondViewModel.transform(input: makeInput(generateInsightsTapped: .just(()))).state
            .asObservable().toBlocking().last()

        XCTAssertEqual(firstState?.insightsSection, .loaded(Self.makeInsights(overview: "owner/First")))
        XCTAssertEqual(secondState?.insightsSection, .loaded(Self.makeInsights(overview: "owner/Second")))
        XCTAssertEqual(insightsService.requestedContexts.map(\.fullName), ["owner/First", "owner/Second"])
    }

    func test_insufficientContextShowsNoticeWithoutCallingService() throws {
        let insightsService = RepositoryInsightsServiceMock()
        let repo = Repo.mock(description: nil, language: nil, topics: [])
        let viewModel = makeViewModel(repo: repo, insightsService: insightsService)
        let output = viewModel.transform(input: makeInput(generateInsightsTapped: .just(())))
        let state = try output.state.asObservable().toBlocking().last()

        XCTAssertEqual(state?.insightsSection, .insufficientData)
        XCTAssertTrue(insightsService.requestedContexts.isEmpty)
    }

    private func makeViewModel(
        repo: Repo = .mock(description: "Repository description"),
        insightsService: RepositoryInsightsServicing
    ) -> RepoDetailsViewModel {
        RepoDetailsViewModel(
            repo: repo,
            service: GitHubServiceMock(),
            insightsService: insightsService
        )
    }

    private func makeInput(
        generateInsightsTapped: Signal<Void> = .empty(),
        viewClosed: Signal<Void> = .empty()
    ) -> RepoDetailsViewModel.Input {
        RepoDetailsViewModel.Input(
            openOnGitHubTapped: .empty(),
            loadDetails: .just(false),
            topicSelected: .empty(),
            generateInsightsTapped: generateInsightsTapped,
            viewClosed: viewClosed
        )
    }

    private static func makeInsights(overview: String) -> RepositoryInsights {
        RepositoryInsights(
            overview: overview,
            usefulFor: ["Developers"],
            nextSteps: ["Read", "Run", "Review"],
            questionsToExplore: ["What is next?"]
        )
    }
}
