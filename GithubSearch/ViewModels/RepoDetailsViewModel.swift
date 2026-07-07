//
//  RepoDetailsViewModel.swift
//  GithubSearch
//
//  Created by Ula on 19/02/2026.
//

import Foundation
import RxSwift
import RxCocoa

final class RepoDetailsViewModel {

    private enum Constants {
        static let titleFallback = L10n.RepoDetails.titleFallback
        static let subtitleFallback = L10n.RepoDetails.subtitleFallback
        static let descriptionFallback = L10n.RepoDetails.descriptionFallback
        static let languageFallback = L10n.RepoDetails.languageFallback
        static let noStarsFallback = L10n.RepoDetails.noStarsFallback
        static let openButtonTitle = L10n.RepoDetails.openButtonTitle
        static let avatarAccessibilityFallback = L10n.RepoDetails.avatarAccessibilityFallback
        static let metadataFallback = L10n.RepoDetails.metadataFallback
        static let topicsFallback = L10n.RepoDetails.topicsFallback
        static let sectionErrorMessage = L10n.RepoDetails.sectionErrorMessage
        static let languagesEmptyMessage = L10n.RepoDetails.languagesEmptyMessage
        static let readmeEmptyMessage = L10n.RepoDetails.readmeEmptyMessage
        static let releaseEmptyMessage = L10n.RepoDetails.releaseEmptyMessage
    }

    struct Input {
        let openOnGitHubTapped: Signal<Void>
        let loadDetails: Signal<Bool>
        let topicSelected: Signal<String>
    }

    struct State: Equatable {
        let title: String
        let subtitle: String
        let subtitleIsSecondary: Bool
        let avatarURL: URL?
        let avatarAccessibilityLabel: String
        let descriptionText: String
        let descriptionIsSecondary: Bool
        let languageText: String
        let languageIsSecondary: Bool
        let starsText: String
        let starsIsSecondary: Bool
        let forksText: String
        let openIssuesText: String
        let watchersText: String
        let updatedText: String
        let updatedAccessibilityLabel: String
        let updatedIsSecondary: Bool
        let defaultBranchText: String
        let defaultBranchIsSecondary: Bool
        let licenseText: String
        let licenseIsSecondary: Bool
        let topics: [String]
        let topicsEmptyText: String
        var languagesSection: LanguagesSectionState
        var readmeSection: ReadmeSectionState
        var releaseSection: ReleaseSectionState
        let openButtonTitle: String
    }

    struct LanguageRowState: Equatable {
        let name: String
        let percentageText: String
        let progress: Float
        let isDimmed: Bool
        let accessibilityLabel: String
    }

    struct LanguagesSectionState: Equatable {
        let isLoading: Bool
        let rows: [LanguageRowState]
        let message: String?
        let isError: Bool
    }

    struct ReadmeSectionState: Equatable {
        let isLoading: Bool
        let previewText: String?
        let message: String?
        let isError: Bool
    }

    struct ReleaseSectionState: Equatable {
        let isLoading: Bool
        let titleText: String?
        let publishedText: String?
        let notesPreviewText: String?
        let message: String?
        let isError: Bool
    }

    struct Output {
        let state: Driver<State>
        let openRepoURL: Signal<URL>
        let topicSelected: Signal<String>
    }

    private let repo: Repo
    private let service: GitHubServiceType
    private let currentDate: () -> Date

    init(
        repo: Repo,
        service: GitHubServiceType = GitHubService(),
        currentDate: @escaping () -> Date = Date.init
    ) {
        self.repo = repo
        self.service = service
        self.currentDate = currentDate
    }

    func transform(input: Input) -> Output {
        let baseState = makeBaseState()
        let repoIdentifier = makeRepoIdentifier()
        let loadRequests = input.loadDetails

        let languagesSection = loadRequests
            .flatMapLatest { [weak self] forceRefresh -> Signal<LanguagesSectionState> in
                guard let self else { return .empty() }
                return self.fetchLanguagesSection(repoIdentifier: repoIdentifier, forceRefresh: forceRefresh)
                    .asSignal(onErrorJustReturn: .failure())
            }
            .asDriver(onErrorJustReturn: .failure())
        let readmeSection = loadRequests
            .flatMapLatest { [weak self] forceRefresh -> Signal<ReadmeSectionState> in
                guard let self else { return .empty() }
                return self.fetchReadmeSection(repoIdentifier: repoIdentifier, forceRefresh: forceRefresh)
                    .asSignal(onErrorJustReturn: .failure())
            }
            .asDriver(onErrorJustReturn: .failure())
        let releaseSection = loadRequests
            .flatMapLatest { [weak self] _ -> Signal<ReleaseSectionState> in
                guard let self else { return .empty() }
                return self.fetchReleaseSection(repoIdentifier: repoIdentifier)
                    .asSignal(onErrorJustReturn: .failure())
            }
            .asDriver(onErrorJustReturn: .failure())

        let state = Driver.combineLatest(languagesSection, readmeSection, releaseSection) { languages, readme, release in
            var state = baseState
            state.languagesSection = languages
            state.readmeSection = readme
            state.releaseSection = release
            return state
        }
        .startWith(baseState)

        let openRepoURL = input.openOnGitHubTapped
            .map { [repo] in repo.htmlUrl }

        return Output(
            state: state,
            openRepoURL: openRepoURL,
            topicSelected: input.topicSelected
        )
    }

    private func makeBaseState() -> State {
        let title = Self.normalized(repo.name) ?? Constants.titleFallback
        let subtitle = Self.normalized(repo.fullName) ?? Constants.subtitleFallback
        let description = Self.normalized(repo.description) ?? Constants.descriptionFallback
        let language = Self.normalized(repo.language) ?? Constants.languageFallback
        let starsCount = max(repo.stargazersCount, 0)
        let exactUpdatedText = RepoDetailsDateFormatter.exactDate(repo.updatedAt) ?? Constants.metadataFallback
        let relativeUpdatedText = RepoDetailsDateFormatter.relativeUpdatedText(
            from: repo.updatedAt,
            now: currentDate()
        ) ?? Constants.metadataFallback
        let defaultBranchText = Self.normalized(repo.defaultBranch) ?? Constants.metadataFallback
        let licenseText = Self.normalized(repo.license?.name) ?? Constants.metadataFallback

        return State(
            title: title,
            subtitle: subtitle,
            subtitleIsSecondary: subtitle == Constants.subtitleFallback,
            avatarURL: repo.owner?.avatarUrl,
            avatarAccessibilityLabel: Self.avatarAccessibilityLabel(login: repo.owner?.login),
            descriptionText: description,
            descriptionIsSecondary: description == Constants.descriptionFallback,
            languageText: language,
            languageIsSecondary: language == Constants.languageFallback,
            starsText: Self.formatStarsText(count: starsCount),
            starsIsSecondary: starsCount == 0,
            forksText: Self.formatCount(repo.forksCount),
            openIssuesText: Self.formatCount(repo.openIssuesCount),
            watchersText: Self.formatCount(repo.watchersCount),
            updatedText: relativeUpdatedText,
            updatedAccessibilityLabel: exactUpdatedText == Constants.metadataFallback ? relativeUpdatedText : "\(relativeUpdatedText), \(exactUpdatedText)",
            updatedIsSecondary: relativeUpdatedText == Constants.metadataFallback,
            defaultBranchText: defaultBranchText,
            defaultBranchIsSecondary: defaultBranchText == Constants.metadataFallback,
            licenseText: licenseText,
            licenseIsSecondary: licenseText == Constants.metadataFallback,
            topics: repo.topics.compactMap(Self.normalized),
            topicsEmptyText: Constants.topicsFallback,
            languagesSection: .loading(),
            readmeSection: .loading(),
            releaseSection: .loading(),
            openButtonTitle: Constants.openButtonTitle
        )
    }

    private func fetchLanguagesSection(repoIdentifier: RepoIdentifier?, forceRefresh: Bool) -> Observable<LanguagesSectionState> {
        guard let repoIdentifier else {
            return .just(.failure())
        }

        return service.fetchLanguages(owner: repoIdentifier.owner, repo: repoIdentifier.name, forceRefresh: forceRefresh)
            .map { languages in
                let visibleLanguages = RepoDetailsLanguageFormatter.visibleLanguages(from: languages)
                guard !visibleLanguages.isEmpty else {
                    return .empty()
                }

                return .loaded(visibleLanguages.map(Self.makeLanguageRowState))
            }
            .asObservable()
            .catchAndReturn(.failure())
            .startWith(.loading())
    }

    private func fetchReadmeSection(repoIdentifier: RepoIdentifier?, forceRefresh: Bool) -> Observable<ReadmeSectionState> {
        guard let repoIdentifier else {
            return .just(.failure())
        }

        return service.fetchReadme(owner: repoIdentifier.owner, repo: repoIdentifier.name, forceRefresh: forceRefresh)
            .map { readme in
                guard let preview = RepoDetailsReadmeFormatter.preview(from: readme?.text) else {
                    return .empty()
                }

                return .loaded(preview)
            }
            .asObservable()
            .catchAndReturn(.failure())
            .startWith(.loading())
    }

    private func fetchReleaseSection(repoIdentifier: RepoIdentifier?) -> Observable<ReleaseSectionState> {
        guard let repoIdentifier else {
            return .just(.failure())
        }

        return service.fetchLatestRelease(owner: repoIdentifier.owner, repo: repoIdentifier.name)
            .map { release in
                guard let release else {
                    return .empty()
                }

                return .loaded(
                    title: Self.releaseTitle(for: release),
                    published: RepoDetailsDateFormatter.exactDate(release.publishedAt) ?? Constants.metadataFallback,
                    notesPreview: RepoDetailsReadmeFormatter.preview(from: release.body)
                )
            }
            .asObservable()
            .catchAndReturn(.failure())
            .startWith(.loading())
    }

    private static func normalized(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func formatStarsText(count: Int) -> String {
        guard count > 0 else {
            return Constants.noStarsFallback
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formattedCount = formatter.string(from: NSNumber(value: count)) ?? "\(count)"
        return L10n.RepoDetails.starsCount(formattedCount)
    }

    private static func formatCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: max(count, 0))) ?? "\(max(count, 0))"
    }

    private static func makeLanguageRowState(language: RepositoryLanguage) -> LanguageRowState {
        let percentageText = RepoDetailsLanguageFormatter.percentageText(language.percentage)
        return LanguageRowState(
            name: language.name,
            percentageText: percentageText,
            progress: Float(max(min(language.percentage / 100, 1), 0)),
            isDimmed: language.percentage < 1,
            accessibilityLabel: L10n.RepoDetails.languageAccessibilityLabel(
                name: language.name,
                percentage: percentageText
            )
        )
    }

    private static func releaseTitle(for release: RepositoryRelease) -> String {
        if release.name == release.tagName {
            return release.name
        }
        return "\(release.name) (\(release.tagName))"
    }

    private static func avatarAccessibilityLabel(login: String?) -> String {
        guard let login = normalized(login) else {
            return Constants.avatarAccessibilityFallback
        }

        return L10n.RepoDetails.avatarAccessibilityLabel(login: login)
    }

    private func makeRepoIdentifier() -> RepoIdentifier? {
        if let owner = Self.normalized(repo.owner?.login),
           let name = Self.normalized(repo.name) {
            return RepoIdentifier(owner: owner, name: name)
        }

        let parts = repo.fullName.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let owner = Self.normalized(parts[0]),
              let name = Self.normalized(parts[1]) else {
            return nil
        }

        return RepoIdentifier(owner: owner, name: name)
    }
}

private struct RepoIdentifier {
    let owner: String
    let name: String
}

private extension RepoDetailsViewModel.LanguagesSectionState {
    static func loading() -> Self {
        Self(isLoading: true, rows: [], message: nil, isError: false)
    }

    static func loaded(_ rows: [RepoDetailsViewModel.LanguageRowState]) -> Self {
        Self(isLoading: false, rows: rows, message: nil, isError: false)
    }

    static func empty() -> Self {
        Self(isLoading: false, rows: [], message: L10n.RepoDetails.languagesEmptyMessage, isError: false)
    }

    static func failure() -> Self {
        Self(isLoading: false, rows: [], message: L10n.RepoDetails.sectionErrorMessage, isError: true)
    }
}

private extension RepoDetailsViewModel.ReadmeSectionState {
    static func loading() -> Self {
        Self(isLoading: true, previewText: nil, message: nil, isError: false)
    }

    static func loaded(_ preview: String) -> Self {
        Self(isLoading: false, previewText: preview, message: nil, isError: false)
    }

    static func empty() -> Self {
        Self(isLoading: false, previewText: nil, message: L10n.RepoDetails.readmeEmptyMessage, isError: false)
    }

    static func failure() -> Self {
        Self(isLoading: false, previewText: nil, message: L10n.RepoDetails.sectionErrorMessage, isError: true)
    }
}

private extension RepoDetailsViewModel.ReleaseSectionState {
    static func loading() -> Self {
        Self(isLoading: true, titleText: nil, publishedText: nil, notesPreviewText: nil, message: nil, isError: false)
    }

    static func loaded(title: String, published: String, notesPreview: String?) -> Self {
        Self(isLoading: false, titleText: title, publishedText: published, notesPreviewText: notesPreview, message: nil, isError: false)
    }

    static func empty() -> Self {
        Self(isLoading: false, titleText: nil, publishedText: nil, notesPreviewText: nil, message: L10n.RepoDetails.releaseEmptyMessage, isError: false)
    }

    static func failure() -> Self {
        Self(isLoading: false, titleText: nil, publishedText: nil, notesPreviewText: nil, message: L10n.RepoDetails.sectionErrorMessage, isError: true)
    }
}

enum RepoDetailsDateFormatter {
    static func exactDate(_ date: Date?) -> String? {
        guard let date else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func relativeUpdatedText(from date: Date?, now: Date, calendar: Calendar = .current) -> String? {
        guard let date else {
            return nil
        }

        if calendar.isDateInToday(date) {
            return L10n.RepoDetails.updatedToday
        }

        let components = calendar.dateComponents([.day, .month, .year], from: date, to: now)
        if let year = components.year, year > 0 {
            return L10n.RepoDetails.updatedYearsAgo(year)
        }
        if let month = components.month, month > 0 {
            return L10n.RepoDetails.updatedMonthsAgo(month)
        }
        if let day = components.day, day > 0 {
            return L10n.RepoDetails.updatedDaysAgo(day)
        }
        return L10n.RepoDetails.updatedToday
    }
}

enum RepoDetailsLanguageFormatter {
    static func visibleLanguages(from languages: [RepositoryLanguage]) -> [RepositoryLanguage] {
        languages.filter { $0.percentage > 0 }
    }

    static func percentageText(_ percentage: Double) -> String {
        guard percentage >= 1 else {
            return "<1%"
        }

        let roundedPercentage = Int(percentage.rounded())
        return "\(roundedPercentage)%"
    }
}

enum RepoDetailsReadmeFormatter {
    static func preview(from text: String?, paragraphLimit: Int = 3, characterLimit: Int = 520) -> String? {
        guard let text else {
            return nil
        }

        let paragraphs = text
            .components(separatedBy: CharacterSet.newlines)
            .reduce(into: [String]()) { result, line in
                let cleanedLine = cleanMarkdownLine(line)
                guard !cleanedLine.isEmpty else {
                    if result.last?.isEmpty == false {
                        result.append("")
                    }
                    return
                }

                if result.isEmpty || result.last == "" {
                    result.append(cleanedLine)
                } else {
                    result[result.count - 1] += " \(cleanedLine)"
                }
            }
            .filter { !$0.isEmpty }

        let preview = paragraphs.prefix(paragraphLimit).joined(separator: "\n\n")
        guard !preview.isEmpty else {
            return nil
        }

        if preview.count > characterLimit {
            let endIndex = preview.index(preview.startIndex, offsetBy: characterLimit)
            return "\(preview[..<endIndex])..."
        }
        return preview
    }

    private static func cleanMarkdownLine(_ line: String) -> String {
        var text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.first == "#" {
            text.removeFirst()
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let removableCharacters = CharacterSet(charactersIn: "`*_>")
        return text.trimmingCharacters(in: removableCharacters.union(.whitespacesAndNewlines))
    }
}
