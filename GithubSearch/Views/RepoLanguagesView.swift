//
//  RepoLanguagesView.swift
//  GithubSearch
//
//  Created by Ula on 07/07/2026.
//

import UIKit
import SnapKit

final class RepoLanguagesView: UIView {
    private let contentStackView = UIStackView()
    private let titleLabel = UILabel()
    private let skeletonStackView = UIStackView()
    private let languagesStackView = UIStackView()
    private let messageLabel = UILabel()

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

    func render(_ state: RepoDetailsViewModel.LanguagesSectionState) {
        skeletonStackView.isHidden = !state.isLoading

        languagesStackView.arrangedSubviews.forEach { view in
            languagesStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        state.rows.forEach { row in
            languagesStackView.addArrangedSubview(makeLanguageRow(row))
        }

        languagesStackView.isHidden = state.rows.isEmpty || state.isLoading
        messageLabel.text = state.message
        messageLabel.textColor = state.isError ? .systemRed : .secondaryLabel
        messageLabel.isHidden = state.message == nil
    }
}

private extension RepoLanguagesView {
    func setupHierarchy() {
        addSubview(contentStackView)
        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(skeletonStackView)
        contentStackView.addArrangedSubview(languagesStackView)
        contentStackView.addArrangedSubview(messageLabel)
    }

    func setupLayout() {
        contentStackView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(RepoDetailsSectionStyle.cardInset)
        }
    }

    func setupStyles() {
        RepoDetailsSectionStyle.configureCard(self)
        RepoDetailsSectionStyle.configureSectionTitle(titleLabel, text: L10n.RepoDetails.languagesSectionTitle)
        RepoDetailsSectionStyle.configureCardStack(contentStackView)
        RepoDetailsSectionStyle.configureSkeletonStack(skeletonStackView, lineCount: 3)
        languagesStackView.axis = .vertical
        languagesStackView.spacing = 12
        RepoDetailsSectionStyle.configureSectionMessage(messageLabel, identifier: "repoDetails.languagesMessageLabel")
    }

    func makeLanguageRow(_ row: RepoDetailsViewModel.LanguageRowState) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 6
        container.isAccessibilityElement = true
        container.accessibilityLabel = row.accessibilityLabel

        let labelRow = UIStackView()
        labelRow.axis = .horizontal
        labelRow.alignment = .firstBaseline
        labelRow.spacing = 12

        let nameLabel = UILabel()
        nameLabel.font = .preferredFont(forTextStyle: .subheadline)
        nameLabel.text = row.name
        nameLabel.textColor = row.isDimmed ? .secondaryLabel : .label
        nameLabel.numberOfLines = 0

        let percentageLabel = UILabel()
        percentageLabel.font = .preferredFont(forTextStyle: .subheadline)
        percentageLabel.textColor = .secondaryLabel
        percentageLabel.text = row.percentageText
        percentageLabel.setContentHuggingPriority(.required, for: .horizontal)

        labelRow.addArrangedSubview(nameLabel)
        labelRow.addArrangedSubview(percentageLabel)

        let progressView = UIProgressView(progressViewStyle: .bar)
        progressView.progress = row.progress
        progressView.progressTintColor = row.isDimmed ? .tertiaryLabel : .systemBlue
        progressView.trackTintColor = .tertiarySystemFill
        progressView.snp.makeConstraints {
            $0.height.equalTo(4)
        }

        container.addArrangedSubview(labelRow)
        container.addArrangedSubview(progressView)
        return container
    }
}
