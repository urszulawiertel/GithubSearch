//
//  L10n.swift
//  GithubSearch
//
//  Created by Ula on 07/04/2026.
//

import Foundation

enum L10n {
    enum Common {
        static let errorTitle = tr("common.error.title")
        static let okButton = tr("common.button.ok")
        static let genericErrorMessage = tr("common.error.message.generic")
    }

    enum Search {
        static let navigationTitle = tr("search.navigation.title")
        static let usernamePlaceholder = tr("search.username.placeholder")
        static let promptMessage = tr("search.prompt.message")
        static let emptyMessage = tr("search.empty.message")
        static let sortButtonTitle = tr("search.sort.button.title")
        static let sortBestMatch = tr("search.sort.best_match")
        static let sortStars = tr("search.sort.stars")
        static let sortUpdated = tr("search.sort.updated")
        static let sortName = tr("search.sort.name")
    }

    enum RepoDetails {
        static let titleFallback = tr("repo.details.title.fallback")
        static let subtitleFallback = tr("repo.details.subtitle.fallback")
        static let descriptionFallback = tr("repo.details.description.fallback")
        static let languageTitle = tr("repo.details.language.title")
        static let languageFallback = tr("repo.details.language.fallback")
        static let starsTitle = tr("repo.details.stars.title")
        static let noStarsFallback = tr("repo.details.stars.fallback")
        static let openButtonTitle = tr("repo.details.open.button.title")
        static let openButtonHint = tr("repo.details.open.button.hint")
        static let avatarAccessibilityFallback = tr("repo.details.avatar.accessibility.fallback")

        static func avatarAccessibilityLabel(login: String) -> String {
            tr("repo.details.avatar.accessibility.label", login)
        }

        static func starsCount(_ count: String) -> String {
            tr("repo.details.stars.count", count)
        }
    }

    enum SearchResults {
        static func starsCount(_ count: Int) -> String {
            tr("search.results.metadata.stars.count", count)
        }
    }

    enum GitHubServiceError {
        static let invalidUsername = tr("github.error.invalid_username")
        static let userNotFound = tr("github.error.user_not_found")
        static let connectivity = tr("github.error.connectivity")
        static let rateLimited = tr("github.error.rate_limited")
    }

    private static func tr(_ key: String, _ args: CVarArg...) -> String {
        let format = NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: key, comment: "")
        guard !args.isEmpty else {
            return format
        }

        return String(format: format, locale: Locale.current, arguments: args)
    }
}
