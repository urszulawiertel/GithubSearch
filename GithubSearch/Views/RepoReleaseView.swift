//
//  RepoReleaseView.swift
//  GithubSearch
//
//  Created by Ula on 07/07/2026.
//

import UIKit
import SnapKit

final class RepoReleaseView: UIView {
    private let contentStackView = UIStackView()
    private let titleLabel = UILabel()
    private let skeletonStackView = UIStackView()
    private let nameLabel = UILabel()
    private let publishedLabel = UILabel()
    private let notesLabel = UILabel()
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

    func render(_ state: RepoDetailsViewModel.ReleaseSectionState) {
        isHidden = !state.isLoading && state.titleText == nil && state.message == L10n.RepoDetails.releaseEmptyMessage
        skeletonStackView.isHidden = !state.isLoading

        nameLabel.text = state.titleText
        nameLabel.isHidden = state.titleText == nil || state.isLoading

        if let publishedText = state.publishedText {
            publishedLabel.text = "\(L10n.RepoDetails.releasePublishedTitle): \(publishedText)"
            publishedLabel.isHidden = state.isLoading
        } else {
            publishedLabel.text = nil
            publishedLabel.isHidden = true
        }

        notesLabel.text = state.notesPreviewText
        notesLabel.isHidden = state.notesPreviewText == nil || state.isLoading
        messageLabel.text = state.message
        messageLabel.textColor = state.isError ? .systemRed : .secondaryLabel
        messageLabel.isHidden = state.message == nil
    }
}

private extension RepoReleaseView {
    func setupHierarchy() {
        addSubview(contentStackView)
        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(skeletonStackView)
        contentStackView.addArrangedSubview(nameLabel)
        contentStackView.addArrangedSubview(publishedLabel)
        contentStackView.addArrangedSubview(notesLabel)
        contentStackView.addArrangedSubview(messageLabel)
    }

    func setupLayout() {
        contentStackView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(RepoDetailsSectionStyle.cardInset)
        }
    }

    func setupStyles() {
        RepoDetailsSectionStyle.configureCard(self)
        RepoDetailsSectionStyle.configureSectionTitle(titleLabel, text: L10n.RepoDetails.releaseSectionTitle)
        RepoDetailsSectionStyle.configureCardStack(contentStackView)
        RepoDetailsSectionStyle.configureSkeletonStack(skeletonStackView, lineCount: 3)

        nameLabel.font = .preferredFont(forTextStyle: .headline)
        nameLabel.numberOfLines = 0
        nameLabel.accessibilityIdentifier = "repoDetails.releaseNameLabel"

        publishedLabel.font = .preferredFont(forTextStyle: .subheadline)
        publishedLabel.textColor = .secondaryLabel
        publishedLabel.numberOfLines = 0
        publishedLabel.accessibilityIdentifier = "repoDetails.releasePublishedLabel"

        RepoDetailsSectionStyle.configureBodyLabel(notesLabel, identifier: "repoDetails.releaseNotesLabel")
        notesLabel.textColor = .secondaryLabel
        RepoDetailsSectionStyle.configureSectionMessage(messageLabel, identifier: "repoDetails.releaseMessageLabel")
    }
}
