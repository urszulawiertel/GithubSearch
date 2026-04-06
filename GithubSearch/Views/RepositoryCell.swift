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

    private enum Constants {
        static let avatarSize: CGFloat = 36
        static let avatarCornerRadius: CGFloat = 10
    }

    private enum AccessibilityID {
        static let cellPrefix = "search.resultCell."
        static let avatarImageView = "search.resultCell.avatarImageView"
        static let nameLabel = "search.resultCell.nameLabel"
        static let descriptionLabel = "search.resultCell.descriptionLabel"
        static let metadataLabel = "search.resultCell.metadataLabel"
    }

    private let imageLoader: ImageLoading
    private var avatarTask: ImageLoadingTask?
    private var currentAvatarURL: URL?

    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = .secondarySystemBackground
        imageView.layer.cornerRadius = Constants.avatarCornerRadius
        imageView.clipsToBounds = true
        imageView.tintColor = .tertiaryLabel
        imageView.accessibilityIdentifier = AccessibilityID.avatarImageView
        return imageView
    }()

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

    private let containerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .top
        stack.spacing = 12
        return stack
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        self.imageLoader = ImageLoader.shared
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
        selectionStyle = .default
        backgroundColor = .clear
        contentView.preservesSuperviewLayoutMargins = true
        setupUI()
        setupLayout()
    }

    init(
        style: UITableViewCell.CellStyle = .default,
        reuseIdentifier: String? = RepositoryCell.reuseID,
        imageLoader: ImageLoading
    ) {
        self.imageLoader = imageLoader
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
        avatarTask?.cancel()
        avatarTask = nil
        currentAvatarURL = nil
        applyAvatarPlaceholder()
        nameLabel.text = nil
        descriptionLabel.text = nil
        metadataLabel.text = nil
        descriptionLabel.isHidden = false
        metadataLabel.isHidden = false
        accessibilityIdentifier = nil
    }

    private func setupUI() {
        contentView.addSubview(containerStack)
        containerStack.addArrangedSubview(avatarImageView)
        containerStack.addArrangedSubview(contentStack)
        contentStack.addArrangedSubview(nameLabel)
        contentStack.addArrangedSubview(descriptionLabel)
        contentStack.addArrangedSubview(metadataLabel)
        applyAvatarPlaceholder()
    }

    private func setupLayout() {
        separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

        containerStack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16))
        }

        avatarImageView.snp.makeConstraints {
            $0.size.equalTo(Constants.avatarSize)
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

        loadAvatar(from: repo.owner?.avatarUrl)
    }

    deinit {
        avatarTask?.cancel()
    }

    private func loadAvatar(from url: URL?) {
        avatarTask?.cancel()
        avatarTask = nil
        currentAvatarURL = url
        applyAvatarPlaceholder()

        guard let url else { return }

        avatarTask = imageLoader.loadImage(from: url) { [weak self] image in
            guard let self, self.currentAvatarURL == url else { return }

            if let image {
                self.avatarImageView.contentMode = .scaleAspectFill
                self.avatarImageView.image = image
            } else {
                self.applyAvatarPlaceholder()
            }

            self.avatarTask = nil
        }
    }

    private func applyAvatarPlaceholder() {
        let configuration = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        avatarImageView.contentMode = .center
        avatarImageView.image = UIImage(
            systemName: "person.crop.circle.fill",
            withConfiguration: configuration
        )
    }
}

#if DEBUG
extension RepositoryCell {
    var displayedAvatarImage: UIImage? {
        avatarImageView.image
    }

    var avatarContentMode: UIView.ContentMode {
        avatarImageView.contentMode
    }
}
#endif
