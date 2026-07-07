//
//  RepoReadmePreviewView.swift
//  GithubSearch
//
//  Created by Ula on 07/07/2026.
//

import UIKit
import SnapKit

final class RepoReadmePreviewView: UIView {
    private let contentStackView = UIStackView()
    private let titleLabel = UILabel()
    private let skeletonStackView = UIStackView()
    private let previewLabel = UILabel()
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

    func render(_ state: RepoDetailsViewModel.ReadmeSectionState) {
        skeletonStackView.isHidden = !state.isLoading

        previewLabel.text = state.previewText
        previewLabel.isHidden = state.previewText == nil || state.isLoading
        messageLabel.text = state.message
        messageLabel.textColor = state.isError ? .systemRed : .secondaryLabel
        messageLabel.isHidden = state.message == nil
    }
}

private extension RepoReadmePreviewView {
    func setupHierarchy() {
        addSubview(contentStackView)
        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(skeletonStackView)
        contentStackView.addArrangedSubview(previewLabel)
        contentStackView.addArrangedSubview(messageLabel)
    }

    func setupLayout() {
        contentStackView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(RepoDetailsSectionStyle.cardInset)
        }
    }

    func setupStyles() {
        RepoDetailsSectionStyle.configureCard(self)
        RepoDetailsSectionStyle.configureSectionTitle(titleLabel, text: L10n.RepoDetails.readmeSectionTitle)
        RepoDetailsSectionStyle.configureCardStack(contentStackView)
        RepoDetailsSectionStyle.configureSkeletonStack(skeletonStackView, lineCount: 4)
        RepoDetailsSectionStyle.configureBodyLabel(previewLabel, identifier: "repoDetails.readmePreviewLabel")
        previewLabel.textColor = .secondaryLabel
        RepoDetailsSectionStyle.configureSectionMessage(messageLabel, identifier: "repoDetails.readmeMessageLabel")
    }
}
