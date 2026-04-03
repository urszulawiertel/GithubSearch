//
//  RepositoryCell.swift
//  GithubSearch
//
//  Created by Ula on 02/04/2026.
//

import UIKit
import SnapKit

final class RepositoryCell: UITableViewCell {

    static let reuseID = "RepositoryCell"
    private enum AccessibilityID {
        static let cellPrefix = "search.resultCell."
        static let nameLabel = "search.resultCell.nameLabel"
        static let descriptionLabel = "search.resultCell.descriptionLabel"
        static let metadataLabel = "search.resultCell.metadataLabel"
    }

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .label
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.accessibilityIdentifier = AccessibilityID.nameLabel
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.accessibilityIdentifier = AccessibilityID.descriptionLabel
        return label
    }()

    private let metadataLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.accessibilityIdentifier = AccessibilityID.metadataLabel
        return label
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
        return stack
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
        selectionStyle = .default
        backgroundColor = .clear
        contentView.preservesSuperviewLayoutMargins = true
        setupUI()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = nil
        descriptionLabel.text = nil
        metadataLabel.text = nil
        descriptionLabel.isHidden = false
        metadataLabel.isHidden = false
        accessibilityIdentifier = nil
    }

    private func setupUI() {
        contentView.addSubview(contentStack)
        contentStack.addArrangedSubview(nameLabel)
        contentStack.addArrangedSubview(descriptionLabel)
        contentStack.addArrangedSubview(metadataLabel)
    }

    private func setupLayout() {
        separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

        contentStack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16))
        }
    }

    func configure(with repo: Repo) {
        accessibilityIdentifier = AccessibilityID.cellPrefix + "\(repo.id)"
        nameLabel.text = repo.name

        let description = repo.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        descriptionLabel.text = description
        descriptionLabel.isHidden = description?.isEmpty != false

        let metadata = [
            repo.language,
            repo.stargazersCount > 0 ? "★ \(repo.stargazersCount)" : nil
        ]
            .compactMap { $0 }
            .joined(separator: "  •  ")

        metadataLabel.text = metadata
        metadataLabel.isHidden = metadata.isEmpty
    }
}
