//
//  GithubSearchUITests.swift
//  GithubSearchUITests
//
//  Created by Ula on 16/02/2026.
//

import XCTest

final class GithubSearchUITests: XCTestCase {

    private enum AccessibilityID {
        static let searchField = "search.usernameField"
        static let resultsTable = "search.resultsTable"
        static let emptyStateLabel = "search.emptyStateLabel"
        static let firstResultCell = "search.resultCell.101"
        static let detailsTitleLabel = "repoDetails.titleLabel"
        static let detailsSubtitleLabel = "repoDetails.subtitleLabel"
        static let detailsDescriptionLabel = "repoDetails.descriptionLabel"
        static let detailsLanguageValueLabel = "repoDetails.languageValueLabel"
        static let detailsStarsValueLabel = "repoDetails.starsValueLabel"
        static let detailsOpenButton = "repoDetails.openOnGitHubButton"
    }

    private enum UITestScenario: String {
        case success
        case empty
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSearchingUsernameOpensRepositoryDetails() throws {
        let app = launchApp(for: .success)

        let searchField = app.searchFields[AccessibilityID.searchField]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        let resultsTable = app.tables[AccessibilityID.resultsTable]
        XCTAssertTrue(resultsTable.exists)

        searchField.tap()
        searchField.typeText("octocat")

        let resultCell = app.cells[AccessibilityID.firstResultCell]
        XCTAssertTrue(resultCell.waitForExistence(timeout: 5))
        resultCell.tap()

        let titleLabel = app.staticTexts[AccessibilityID.detailsTitleLabel]
        XCTAssertTrue(titleLabel.waitForExistence(timeout: 5))
        XCTAssertEqual(titleLabel.label, "ios-github-search")

        let subtitleLabel = app.staticTexts[AccessibilityID.detailsSubtitleLabel]
        XCTAssertEqual(subtitleLabel.label, "octocat/ios-github-search")

        let descriptionLabel = app.staticTexts[AccessibilityID.detailsDescriptionLabel]
        XCTAssertEqual(descriptionLabel.label, "UI test repository for the main search flow.")

        let languageValueLabel = app.staticTexts[AccessibilityID.detailsLanguageValueLabel]
        XCTAssertEqual(languageValueLabel.label, "Swift")

        let starsValueLabel = app.staticTexts[AccessibilityID.detailsStarsValueLabel]
        XCTAssertEqual(starsValueLabel.label, "★ 42")

        let openOnGitHubButton = app.buttons[AccessibilityID.detailsOpenButton]
        XCTAssertTrue(openOnGitHubButton.exists)
        XCTAssertEqual(openOnGitHubButton.label, "Open on GitHub")
    }

    func testSearchingUsernameWithNoRepositoriesShowsEmptyState() throws {
        let app = launchApp(for: .empty)

        let searchField = app.searchFields[AccessibilityID.searchField]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        let resultsTable = app.tables[AccessibilityID.resultsTable]
        XCTAssertTrue(resultsTable.exists)

        searchField.tap()
        searchField.typeText("ghost-user")

        let emptyStateLabel = app.staticTexts[AccessibilityID.emptyStateLabel]
        XCTAssertTrue(emptyStateLabel.waitForExistence(timeout: 5))
        XCTAssertEqual(emptyStateLabel.label, "No public repositories found.")

        XCTAssertFalse(app.cells[AccessibilityID.firstResultCell].exists)
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    private func launchApp(for scenario: UITestScenario) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario.rawValue
        app.launch()
        return app
    }
}
