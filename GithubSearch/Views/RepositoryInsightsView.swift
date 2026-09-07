//
//  RepositoryInsightsView.swift
//  GithubSearch
//

import UIKit
import SnapKit

final class RepositoryInsightsView: UIView {
    let generateButton = UIButton(type: .system)

    private let contentStackView = UIStackView()
    private let titleLabel = UILabel()
    private let explanationLabel = UILabel()
    private let statusStackView = UIStackView()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let statusLabel = UILabel()
    private let analysisStackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupHierarchy()
        setupLayout()
        setupStyles()
        render(.idle)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func render(_ state: RepositoryInsightsState) {
        resetContent()

        switch state {
        case .idle:
            explanationLabel.isHidden = false
            configureButton(title: L10n.RepositoryInsights.generateButton, isEnabled: true)
        case .loading:
            statusStackView.isHidden = false
            activityIndicator.startAnimating()
            statusLabel.text = L10n.RepositoryInsights.loadingMessage
            statusLabel.textColor = .secondaryLabel
            statusLabel.accessibilityIdentifier = "repoInsights.loadingLabel"
            configureButton(title: L10n.RepositoryInsights.generatingButton, isEnabled: false)
        case let .loaded(insights):
            analysisStackView.isHidden = false
            render(insights)
            configureButton(title: L10n.RepositoryInsights.regenerateButton, isEnabled: true)
        case .insufficientData:
            statusStackView.isHidden = false
            statusLabel.text = L10n.RepositoryInsights.insufficientDataMessage
            statusLabel.textColor = .secondaryLabel
            statusLabel.accessibilityIdentifier = "repoInsights.insufficientDataLabel"
            configureButton(title: L10n.RepositoryInsights.generateButton, isEnabled: true)
        case .failed:
            statusStackView.isHidden = false
            statusLabel.text = L10n.RepositoryInsights.errorMessage
            statusLabel.textColor = .systemRed
            statusLabel.accessibilityIdentifier = "repoInsights.errorLabel"
            configureButton(title: L10n.RepositoryInsights.retryButton, isEnabled: true)
        }
    }
}

private extension RepositoryInsightsView {
    func setupHierarchy() {
        addSubview(contentStackView)
        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(explanationLabel)
        statusStackView.addArrangedSubview(activityIndicator)
        statusStackView.addArrangedSubview(statusLabel)
        contentStackView.addArrangedSubview(statusStackView)
        contentStackView.addArrangedSubview(analysisStackView)
        contentStackView.addArrangedSubview(generateButton)
    }

    func setupLayout() {
        contentStackView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(16)
        }

        generateButton.snp.makeConstraints {
            $0.height.greaterThanOrEqualTo(44)
        }
    }

    func setupStyles() {
        RepoDetailsSectionStyle.configureCard(self)

        contentStackView.axis = .vertical
        contentStackView.alignment = .fill
        contentStackView.spacing = 12

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.text = L10n.RepositoryInsights.sectionTitle
        titleLabel.accessibilityIdentifier = "repoInsights.titleLabel"

        explanationLabel.font = .preferredFont(forTextStyle: .subheadline)
        explanationLabel.adjustsFontForContentSizeCategory = true
        explanationLabel.textColor = .secondaryLabel
        explanationLabel.numberOfLines = 0
        explanationLabel.text = L10n.RepositoryInsights.explanation
        explanationLabel.accessibilityIdentifier = "repoInsights.explanationLabel"

        statusStackView.axis = .horizontal
        statusStackView.alignment = .center
        statusStackView.spacing = 10

        activityIndicator.hidesWhenStopped = true
        activityIndicator.accessibilityIdentifier = "repoInsights.activityIndicator"

        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.numberOfLines = 0

        analysisStackView.axis = .vertical
        analysisStackView.alignment = .fill
        analysisStackView.spacing = 12

        var configuration = UIButton.Configuration.tinted()
        configuration.cornerStyle = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        generateButton.configuration = configuration
        generateButton.accessibilityIdentifier = "repoInsights.generateButton"
        generateButton.accessibilityHint = L10n.RepositoryInsights.buttonHint
    }

    func resetContent() {
        explanationLabel.isHidden = true
        statusStackView.isHidden = true
        analysisStackView.isHidden = true
        activityIndicator.stopAnimating()
        statusLabel.text = nil
        analysisStackView.arrangedSubviews.forEach { view in
            analysisStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    func configureButton(title: String, isEnabled: Bool) {
        generateButton.configuration?.title = title
        generateButton.isEnabled = isEnabled
    }

    func render(_ insights: RepositoryInsights) {
        analysisStackView.addArrangedSubview(makeSection(
            title: L10n.RepositoryInsights.overviewTitle,
            items: [insights.overview],
            accessibilityIdentifier: "repoInsights.overview"
        ))
        analysisStackView.addArrangedSubview(makeSection(
            title: L10n.RepositoryInsights.usefulForTitle,
            items: insights.usefulFor,
            accessibilityIdentifier: "repoInsights.usefulFor"
        ))
        analysisStackView.addArrangedSubview(makeSection(
            title: L10n.RepositoryInsights.nextStepsTitle,
            items: insights.nextSteps,
            accessibilityIdentifier: "repoInsights.nextSteps"
        ))
        analysisStackView.addArrangedSubview(makeSection(
            title: L10n.RepositoryInsights.questionsTitle,
            items: insights.questionsToExplore,
            accessibilityIdentifier: "repoInsights.questions"
        ))
    }

    func makeSection(title: String, items: [String], accessibilityIdentifier: String) -> UIStackView {
        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label
        titleLabel.text = title

        let itemsLabel = UILabel()
        itemsLabel.font = .preferredFont(forTextStyle: .body)
        itemsLabel.adjustsFontForContentSizeCategory = true
        itemsLabel.textColor = .secondaryLabel
        itemsLabel.numberOfLines = 0
        itemsLabel.text = items.count == 1 ? items[0] : items.map { "• \($0)" }.joined(separator: "\n")
        itemsLabel.accessibilityIdentifier = accessibilityIdentifier

        let stackView = UIStackView(arrangedSubviews: [titleLabel, itemsLabel])
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 4
        return stackView
    }
}
