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
        static let forksTitle = tr("repo.details.forks.title")
        static let openIssuesTitle = tr("repo.details.open_issues.title")
        static let watchersTitle = tr("repo.details.watchers.title")
        static let updatedTitle = tr("repo.details.updated.title")
        static let defaultBranchTitle = tr("repo.details.default_branch.title")
        static let licenseTitle = tr("repo.details.license.title")
        static let metadataFallback = tr("repo.details.metadata.fallback")
        static let topicsTitle = tr("repo.details.topics.title")
        static let topicsFallback = tr("repo.details.topics.fallback")
        static let languagesSectionTitle = tr("repo.details.languages.section.title")
        static let languagesEmptyMessage = tr("repo.details.languages.empty")
        static let readmeSectionTitle = tr("repo.details.readme.section.title")
        static let readmeEmptyMessage = tr("repo.details.readme.empty")
        static let releaseSectionTitle = tr("repo.details.release.section.title")
        static let releasePublishedTitle = tr("repo.details.release.published.title")
        static let releaseEmptyMessage = tr("repo.details.release.empty")
        static let sectionLoadingMessage = tr("repo.details.section.loading")
        static let sectionErrorMessage = tr("repo.details.section.error")
        static let updatedToday = tr("repo.details.updated.today")
        static let openButtonTitle = tr("repo.details.open.button.title")
        static let openButtonHint = tr("repo.details.open.button.hint")
        static let avatarAccessibilityFallback = tr("repo.details.avatar.accessibility.fallback")

        static func updatedDaysAgo(_ count: Int) -> String {
            tr("repo.details.updated.days_ago", count)
        }

        static func updatedMonthsAgo(_ count: Int) -> String {
            tr("repo.details.updated.months_ago", count)
        }

        static func updatedYearsAgo(_ count: Int) -> String {
            tr("repo.details.updated.years_ago", count)
        }

        static func avatarAccessibilityLabel(login: String) -> String {
            tr("repo.details.avatar.accessibility.label", login)
        }

        static func languageAccessibilityLabel(name: String, percentage: String) -> String {
            tr("repo.details.language.accessibility.label", name, percentage)
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
