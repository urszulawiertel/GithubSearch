//
//  RepoDetailsView.swift
//  GithubSearch
//
//  Created by Ula on 06/07/2026.
//

import UIKit
import SnapKit

final class RepoDetailsView: UIView {

    private enum Constants {
        static let contentInset: CGFloat = 16
        static let avatarSize: CGFloat = 56
        static let avatarCornerRadius: CGFloat = 12
        static let cardCornerRadius: CGFloat = 14
        static let cardInset: CGFloat = 16
    }

    let refreshControl = UIRefreshControl()
    let avatarImageView = UIImageView()
    let openOnGitHubButton = UIButton(type: .system)

    var onTopicSelected: ((String) -> Void)? {
        didSet {
            topicsView.onTopicSelected = onTopicSelected
        }
    }

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let contentStackView = UIStackView()
    private let headerCardView = UIView()
    private let headerContentView = UIView()
    private let headerTopRowStackView = UIStackView()
    private let headerTextStackView = UIStackView()

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let descriptionLabel = UILabel()

    private let languageTitleLabel = UILabel()
    private let languageValueLabel = UILabel()

    private let starsTitleLabel = UILabel()
    private let starsValueLabel = UILabel()

    private let forksTitleLabel = UILabel()
    private let forksValueLabel = UILabel()

    private let openIssuesTitleLabel = UILabel()
    private let openIssuesValueLabel = UILabel()

    private let watchersTitleLabel = UILabel()
    private let watchersValueLabel = UILabel()

    private let updatedTitleLabel = UILabel()
    private let updatedValueLabel = UILabel()

    private let statsCardView = UIView()
    private let statsStackView = UIStackView()
    private let metadataCardView = UIView()
    private let metadataStackView = UIStackView()
    private let defaultBranchTitleLabel = UILabel()
    private let defaultBranchValueLabel = UILabel()
    private let licenseTitleLabel = UILabel()
    private let licenseValueLabel = UILabel()

    private let topicsView = RepoTopicsView()
    private let languagesView = RepoLanguagesView()
    private let readmePreviewView = RepoReadmePreviewView()
    private let releaseView = RepoReleaseView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupHierarchy()
        setupLayout()
        setupStyles()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func render(_ state: RepoDetailsViewModel.State) {
        titleLabel.text = state.title
        subtitleLabel.text = state.subtitle
        subtitleLabel.textColor = state.subtitleIsSecondary ? .tertiaryLabel : .secondaryLabel

        descriptionLabel.text = state.descriptionText
        descriptionLabel.textColor = state.descriptionIsSecondary ? .secondaryLabel : .label

        languageValueLabel.text = state.languageText
        languageValueLabel.textColor = state.languageIsSecondary ? .secondaryLabel : .label

        starsValueLabel.text = state.starsText
        starsValueLabel.textColor = state.starsIsSecondary ? .secondaryLabel : .label
        forksValueLabel.text = state.forksText
        openIssuesValueLabel.text = state.openIssuesText
        watchersValueLabel.text = state.watchersText
        updatedValueLabel.text = state.updatedText
        updatedValueLabel.accessibilityLabel = state.updatedAccessibilityLabel
        updatedValueLabel.textColor = state.updatedIsSecondary ? .secondaryLabel : .label
        defaultBranchValueLabel.text = state.defaultBranchText
        defaultBranchValueLabel.textColor = state.defaultBranchIsSecondary ? .secondaryLabel : .label
        licenseValueLabel.text = state.licenseText
        licenseValueLabel.textColor = state.licenseIsSecondary ? .secondaryLabel : .label

        topicsView.render(topics: state.topics, emptyText: state.topicsEmptyText)
        languagesView.render(state.languagesSection)
        readmePreviewView.render(state.readmeSection)
        releaseView.render(state.releaseSection)

        openOnGitHubButton.configuration?.title = state.openButtonTitle
    }

    func endRefreshing() {
        refreshControl.endRefreshing()
    }
}

// MARK: - Setup

private extension RepoDetailsView {
    private func setupHierarchy() {
        scrollView.refreshControl = refreshControl
        addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(contentStackView)

        headerCardView.addSubview(headerContentView)
        headerContentView.addSubview(headerTopRowStackView)
        headerTopRowStackView.addArrangedSubview(avatarImageView)
        headerTopRowStackView.addArrangedSubview(headerTextStackView)
        headerTextStackView.addArrangedSubview(titleLabel)
        headerTextStackView.addArrangedSubview(subtitleLabel)
        headerContentView.addSubview(descriptionLabel)

        contentStackView.addArrangedSubview(headerCardView)

        statsStackView.addArrangedSubview(makeStatView(titleLabel: starsTitleLabel, valueLabel: starsValueLabel))
        statsStackView.addArrangedSubview(makeStatView(titleLabel: forksTitleLabel, valueLabel: forksValueLabel))
        statsStackView.addArrangedSubview(makeStatView(titleLabel: openIssuesTitleLabel, valueLabel: openIssuesValueLabel))
        statsStackView.addArrangedSubview(makeStatView(titleLabel: watchersTitleLabel, valueLabel: watchersValueLabel))
        statsCardView.addSubview(statsStackView)
        contentStackView.addArrangedSubview(statsCardView)

        metadataStackView.addArrangedSubview(makeMetadataRow(titleLabel: languageTitleLabel, valueLabel: languageValueLabel))
        metadataStackView.addArrangedSubview(makeMetadataRow(titleLabel: updatedTitleLabel, valueLabel: updatedValueLabel))
        metadataStackView.addArrangedSubview(makeMetadataRow(titleLabel: defaultBranchTitleLabel, valueLabel: defaultBranchValueLabel))
        metadataStackView.addArrangedSubview(makeMetadataRow(titleLabel: licenseTitleLabel, valueLabel: licenseValueLabel))
        metadataCardView.addSubview(metadataStackView)
        contentStackView.addArrangedSubview(metadataCardView)

        contentStackView.addArrangedSubview(topicsView)
        contentStackView.addArrangedSubview(languagesView)
        contentStackView.addArrangedSubview(readmePreviewView)
        contentStackView.addArrangedSubview(releaseView)
        contentStackView.addArrangedSubview(openOnGitHubButton)
    }

    private func setupLayout() {
        scrollView.snp.makeConstraints {
            $0.edges.equalTo(safeAreaLayoutGuide)
        }

        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.width.equalTo(scrollView.snp.width)
        }

        contentStackView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(Constants.contentInset)
        }

        setupCardLayouts()
    }

    private func setupCardLayouts() {
        headerContentView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(Constants.cardInset)
        }

        headerCardView.snp.makeConstraints {
            $0.height.greaterThanOrEqualTo(Constants.avatarSize)
        }

        headerTopRowStackView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
        }

        avatarImageView.snp.makeConstraints {
            $0.size.equalTo(Constants.avatarSize)
        }

        descriptionLabel.snp.makeConstraints {
            $0.top.equalTo(headerTopRowStackView.snp.bottom).offset(14)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        statsStackView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(Constants.cardInset)
        }

        metadataStackView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(Constants.cardInset)
        }

    }

    private func setupStyles() {
        backgroundColor = .systemGroupedBackground

        contentStackView.axis = .vertical
        contentStackView.alignment = .fill
        contentStackView.spacing = 14

        [
            headerCardView,
            statsCardView,
            metadataCardView
        ].forEach(RepoDetailsSectionStyle.configureCard)

        refreshControl.tintColor = .secondaryLabel
        configureHeaderStyles()

        configureMetadataLabel(languageTitleLabel, text: L10n.RepoDetails.languageTitle)
        configureValueLabel(languageValueLabel, identifier: "repoDetails.languageValueLabel")

        configureStatLabel(starsTitleLabel, text: L10n.RepoDetails.starsTitle)
        configureStatValueLabel(starsValueLabel, identifier: "repoDetails.starsValueLabel")

        configureStatValueLabel(forksValueLabel, identifier: "repoDetails.forksValueLabel")
        configureStatValueLabel(openIssuesValueLabel, identifier: "repoDetails.openIssuesValueLabel")
        configureStatValueLabel(watchersValueLabel, identifier: "repoDetails.watchersValueLabel")
        configureStatLabel(forksTitleLabel, text: L10n.RepoDetails.forksTitle)
        configureStatLabel(openIssuesTitleLabel, text: L10n.RepoDetails.openIssuesTitle)
        configureStatLabel(watchersTitleLabel, text: L10n.RepoDetails.watchersTitle)
        configureMetadataLabel(updatedTitleLabel, text: L10n.RepoDetails.updatedTitle)
        configureValueLabel(updatedValueLabel, identifier: "repoDetails.updatedValueLabel")
        configureMetadataLabel(defaultBranchTitleLabel, text: L10n.RepoDetails.defaultBranchTitle)
        configureValueLabel(defaultBranchValueLabel, identifier: "repoDetails.defaultBranchValueLabel")
        configureMetadataLabel(licenseTitleLabel, text: L10n.RepoDetails.licenseTitle)
        configureValueLabel(licenseValueLabel, identifier: "repoDetails.licenseValueLabel")

        statsStackView.axis = .horizontal
        statsStackView.alignment = .fill
        statsStackView.distribution = .fillEqually
        statsStackView.spacing = 8

        metadataStackView.axis = .vertical
        metadataStackView.alignment = .fill
        metadataStackView.spacing = 10

        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .medium
        configuration.baseBackgroundColor = .systemBlue
        configuration.baseForegroundColor = .white
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        openOnGitHubButton.configuration = configuration
        openOnGitHubButton.accessibilityIdentifier = "repoDetails.openOnGitHubButton"
        openOnGitHubButton.accessibilityHint = L10n.RepoDetails.openButtonHint
        openOnGitHubButton.snp.makeConstraints {
            $0.height.equalTo(48)
        }
    }

    private func configureHeaderStyles() {
        headerTopRowStackView.axis = .horizontal
        headerTopRowStackView.alignment = .top
        headerTopRowStackView.spacing = 12

        headerTextStackView.axis = .vertical
        headerTextStackView.alignment = .fill
        headerTextStackView.spacing = 6
        headerTextStackView.setContentCompressionResistancePriority(.required, for: .vertical)

        avatarImageView.backgroundColor = .secondarySystemBackground
        avatarImageView.layer.cornerRadius = Constants.avatarCornerRadius
        avatarImageView.clipsToBounds = true
        avatarImageView.tintColor = .tertiaryLabel
        avatarImageView.isAccessibilityElement = true
        avatarImageView.setContentHuggingPriority(.required, for: .horizontal)
        avatarImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        avatarImageView.accessibilityIdentifier = "repoDetails.avatarImageView"

        configureHeaderLabel(titleLabel, textStyle: .title2, textColor: .label, identifier: "repoDetails.titleLabel")
        configureHeaderLabel(subtitleLabel, textStyle: .subheadline, textColor: .secondaryLabel, identifier: "repoDetails.subtitleLabel")
        configureHeaderLabel(descriptionLabel, textStyle: .body, textColor: .secondaryLabel, identifier: "repoDetails.descriptionLabel")
    }

    private func configureHeaderLabel(_ label: UILabel, textStyle: UIFont.TextStyle, textColor: UIColor, identifier: String) {
        label.font = .preferredFont(forTextStyle: textStyle)
        label.textColor = textColor
        label.numberOfLines = 0
        label.isAccessibilityElement = true
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.accessibilityIdentifier = identifier
    }

    private func makeMetadataRow(titleLabel: UILabel, valueLabel: UILabel) -> UIStackView {
        let stackView = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stackView.axis = .horizontal
        stackView.alignment = .firstBaseline
        stackView.spacing = 8
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return stackView
    }

    private func makeStatView(titleLabel: UILabel, valueLabel: UILabel) -> UIStackView {
        let stackView = UIStackView(arrangedSubviews: [valueLabel, titleLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 4
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2)
        return stackView
    }

    private func configureMetadataLabel(_ label: UILabel, text: String) {
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabel
        label.text = text
    }

    private func configureStatLabel(_ label: UILabel, text: String) {
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.text = text
        label.numberOfLines = 2
        label.adjustsFontForContentSizeCategory = true
    }

    private func configureStatValueLabel(_ label: UILabel, identifier: String) {
        label.font = .preferredFont(forTextStyle: .headline)
        label.textAlignment = .center
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        label.accessibilityIdentifier = identifier
    }

    private func configureValueLabel(_ label: UILabel, identifier: String) {
        label.font = .preferredFont(forTextStyle: .caption1)
        label.numberOfLines = 0
        label.accessibilityIdentifier = identifier
    }
}
