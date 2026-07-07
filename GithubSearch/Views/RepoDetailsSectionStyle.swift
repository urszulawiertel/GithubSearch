//
//  RepoDetailsSectionStyle.swift
//  GithubSearch
//
//  Created by Ula on 07/07/2026.
//

import UIKit
import SnapKit

enum RepoDetailsSectionStyle {
    static let cardInset: CGFloat = 16
    static let cardCornerRadius: CGFloat = 14

    static func configureCard(_ view: UIView) {
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = cardCornerRadius
        view.layer.cornerCurve = .continuous
    }

    static func configureCardStack(_ stackView: UIStackView) {
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 12
    }

    static func configureSectionTitle(_ label: UILabel, text: String) {
        label.font = .preferredFont(forTextStyle: .headline)
        label.text = text
        label.numberOfLines = 0
    }

    static func configureBodyLabel(_ label: UILabel, identifier: String) {
        label.font = .preferredFont(forTextStyle: .body)
        label.numberOfLines = 0
        label.accessibilityIdentifier = identifier
    }

    static func configureSectionMessage(_ label: UILabel, identifier: String) {
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.accessibilityIdentifier = identifier
    }

    static func configureSkeletonStack(_ stackView: UIStackView, lineCount: Int) {
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.accessibilityLabel = L10n.RepoDetails.sectionLoadingMessage

        (0..<lineCount).forEach { index in
            let skeletonView = UIView()
            skeletonView.backgroundColor = .tertiarySystemFill
            skeletonView.layer.cornerRadius = 5
            skeletonView.layer.cornerCurve = .continuous
            skeletonView.alpha = index == lineCount - 1 ? 0.55 : 1
            stackView.addArrangedSubview(skeletonView)
            skeletonView.snp.makeConstraints {
                $0.height.equalTo(index == 0 ? 16 : 12)
                if index == lineCount - 1 {
                    $0.width.equalToSuperview().multipliedBy(0.62)
                }
            }
        }
    }
}
