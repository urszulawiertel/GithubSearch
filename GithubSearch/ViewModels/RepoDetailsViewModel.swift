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
        static let titleFallback = "Repository"
        static let subtitleFallback = "Full name unavailable"
        static let descriptionFallback = "No description provided."
        static let languageFallback = "Not specified"
        static let noStarsFallback = "No stars yet"
        static let openButtonTitle = "Open on GitHub"
    }

    struct Input {
        let openOnGitHubTapped: Signal<Void>
    }

    struct State: Equatable {
        let title: String
        let subtitle: String
        let subtitleIsSecondary: Bool
        let avatarURL: URL?
        let descriptionText: String
        let descriptionIsSecondary: Bool
        let languageText: String
        let languageIsSecondary: Bool
        let starsText: String
        let starsIsSecondary: Bool
        let openButtonTitle: String
    }

    struct Output {
        let state: Driver<State>
        let openRepoURL: Signal<URL>
    }

    private let repo: Repo

    init(repo: Repo) {
        self.repo = repo
    }

    func transform(input: Input) -> Output {
        let title = Self.normalized(repo.name) ?? Constants.titleFallback
        let subtitle = Self.normalized(repo.fullName) ?? Constants.subtitleFallback
        let description = Self.normalized(repo.description) ?? Constants.descriptionFallback
        let language = Self.normalized(repo.language) ?? Constants.languageFallback
        let starsCount = max(repo.stargazersCount, 0)

        let state = State(
            title: title,
            subtitle: subtitle,
            subtitleIsSecondary: subtitle == Constants.subtitleFallback,
            avatarURL: repo.owner?.avatarUrl,
            descriptionText: description,
            descriptionIsSecondary: description == Constants.descriptionFallback,
            languageText: language,
            languageIsSecondary: language == Constants.languageFallback,
            starsText: Self.formatStarsText(count: starsCount),
            starsIsSecondary: starsCount == 0,
            openButtonTitle: Constants.openButtonTitle
        )

        let openRepoURL = input.openOnGitHubTapped
            .map { [repo] in repo.htmlUrl }

        return Output(
            state: Driver.just(state),
            openRepoURL: openRepoURL
        )
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
        return "★ \(formattedCount)"
    }
}
