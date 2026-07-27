//
//  SearchPlaceholderView.swift
//  GithubSearch
//
//  Created by Ula on 27/07/2026.
//

import UIKit
import SnapKit

final class SearchPlaceholderView: UIView {

    private enum Constants {
        static let symbolName = "person.crop.circle.badge.questionmark"
        static let symbolPointSize: CGFloat = 52
        static let contentSpacing: CGFloat = 12
        static let textSpacing: CGFloat = 6
    }

    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        imageView.image = UIImage(
            systemName: Constants.symbolName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: Constants.symbolPointSize)
        )
        imageView.tintColor = .secondaryLabel
        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = false

        titleLabel.text = L10n.Search.userNotFoundTitle
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0

        descriptionLabel.text = L10n.Search.userNotFoundDescription
        descriptionLabel.font = .preferredFont(forTextStyle: .body)
        descriptionLabel.adjustsFontForContentSizeCategory = true
        descriptionLabel.textAlignment = .center
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0

        isAccessibilityElement = true
        accessibilityLabel = [
            L10n.Search.userNotFoundTitle,
            L10n.Search.userNotFoundDescription
        ].joined(separator: ". ")

        addSubview(imageView)
        addSubview(titleLabel)
        addSubview(descriptionLabel)
    }

    private func setupLayout() {
        imageView.snp.makeConstraints {
            $0.top.centerX.equalToSuperview()
        }

        titleLabel.snp.makeConstraints {
            $0.top.equalTo(imageView.snp.bottom).offset(Constants.contentSpacing)
            $0.leading.trailing.equalToSuperview()
        }

        descriptionLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Constants.textSpacing)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }
}
