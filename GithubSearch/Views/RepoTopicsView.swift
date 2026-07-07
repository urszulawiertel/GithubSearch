//
//  RepoTopicsView.swift
//  GithubSearch
//
//  Created by Ula on 07/07/2026.
//

import UIKit

final class RepoTopicsView: UIView {
    var onTopicSelected: ((String) -> Void)?

    private let contentStackView = UIStackView()
    private let titleLabel = UILabel()
    private let topicsStackView = UIStackView()
    private let topicsMessageLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupHierarchy()
        setupStyles()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func render(topics: [String], emptyText: String) {
        topicsStackView.arrangedSubviews.forEach { view in
            topicsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard !topics.isEmpty else {
            topicsStackView.isHidden = true
            topicsMessageLabel.text = emptyText
            topicsMessageLabel.isHidden = false
            return
        }

        topicsMessageLabel.isHidden = true
        topicsStackView.isHidden = false

        var currentRow = makeTopicRow()
        topicsStackView.addArrangedSubview(currentRow)
        topics.enumerated().forEach { index, topic in
            if index > 0, index % 3 == 0 {
                currentRow = makeTopicRow()
                topicsStackView.addArrangedSubview(currentRow)
            }
            currentRow.addArrangedSubview(makeTopicButton(title: topic))
        }
    }
}

private extension RepoTopicsView {
    func setupHierarchy() {
        addSubview(contentStackView)
        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(topicsStackView)
        contentStackView.addArrangedSubview(topicsMessageLabel)
    }

    func setupStyles() {
        contentStackView.axis = .vertical
        contentStackView.alignment = .fill
        contentStackView.spacing = 8
        contentStackView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        RepoDetailsSectionStyle.configureSectionTitle(titleLabel, text: L10n.RepoDetails.topicsTitle)
        topicsStackView.axis = .vertical
        topicsStackView.spacing = 8
        RepoDetailsSectionStyle.configureSectionMessage(
            topicsMessageLabel,
            identifier: "repoDetails.topicsMessageLabel"
        )
    }

    func makeTopicRow() -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .leading
        stackView.spacing = 8
        return stackView
    }

    func makeTopicButton(title: String) -> UIButton {
        var configuration = UIButton.Configuration.tinted()
        configuration.cornerStyle = .capsule
        configuration.title = title
        configuration.baseForegroundColor = .systemBlue
        configuration.baseBackgroundColor = .systemBlue
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)

        let button = UIButton(type: .system)
        button.configuration = configuration
        button.accessibilityLabel = title
        button.addAction(UIAction { [weak self] _ in
            self?.onTopicSelected?(title)
        }, for: .touchUpInside)
        return button
    }
}
