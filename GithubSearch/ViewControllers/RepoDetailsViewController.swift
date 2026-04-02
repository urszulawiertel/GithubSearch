//
//  RepoDetailsViewController.swift
//  GithubSearch
//
//  Created by Ula on 19/02/2026.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import SafariServices

final class RepoDetailsViewController: UIViewController {

    private let disposeBag = DisposeBag()
    private let viewModel: RepoDetailsViewModel

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    fileprivate let titleLabel = UILabel()
    fileprivate let subtitleLabel = UILabel()
    fileprivate let descriptionLabel = UILabel()

    fileprivate let languageTitleLabel = UILabel()
    fileprivate let languageValueLabel = UILabel()

    private let starsTitleLabel = UILabel()
    fileprivate let starsValueLabel = UILabel()

    fileprivate let openOnGitHubButton = UIButton(type: .system)

    // MARK: - Init

    init(viewModel: RepoDetailsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        setupHierarchy()
        setupLayout()
        setupStyles()
        setupBindings()
    }

    // MARK: - Setup

    private func setupHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(descriptionLabel)

        contentView.addSubview(languageTitleLabel)
        contentView.addSubview(languageValueLabel)

        contentView.addSubview(starsTitleLabel)
        contentView.addSubview(starsValueLabel)

        contentView.addSubview(openOnGitHubButton)
    }

    private func setupLayout() {
        scrollView.snp.makeConstraints {
            $0.edges.equalTo(view.safeAreaLayoutGuide)
        }

        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.width.equalTo(scrollView.snp.width)
        }

        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().inset(16)
            $0.leading.trailing.equalToSuperview().inset(16)
        }

        subtitleLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(6)
            $0.leading.trailing.equalToSuperview().inset(16)
        }

        descriptionLabel.snp.makeConstraints {
            $0.top.equalTo(subtitleLabel.snp.bottom).offset(12)
            $0.leading.trailing.equalToSuperview().inset(16)
        }

        languageTitleLabel.snp.makeConstraints {
            $0.top.equalTo(descriptionLabel.snp.bottom).offset(16)
            $0.leading.equalToSuperview().inset(16)
        }

        languageValueLabel.snp.makeConstraints {
            $0.centerY.equalTo(languageTitleLabel)
            $0.leading.equalTo(languageTitleLabel.snp.trailing).offset(8)
            $0.trailing.lessThanOrEqualToSuperview().inset(16)
        }

        starsTitleLabel.snp.makeConstraints {
            $0.top.equalTo(languageTitleLabel.snp.bottom).offset(10)
            $0.leading.equalToSuperview().inset(16)
        }

        starsValueLabel.snp.makeConstraints {
            $0.centerY.equalTo(starsTitleLabel)
            $0.leading.equalTo(starsTitleLabel.snp.trailing).offset(8)
            $0.trailing.lessThanOrEqualToSuperview().inset(16)
        }

        openOnGitHubButton.snp.makeConstraints {
            $0.top.equalTo(starsTitleLabel.snp.bottom).offset(18)
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.height.equalTo(48)
            $0.bottom.equalToSuperview().inset(20)
        }
    }

    private func setupStyles() {
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityIdentifier = "repoDetails.titleLabel"

        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.accessibilityIdentifier = "repoDetails.subtitleLabel"

        descriptionLabel.font = .preferredFont(forTextStyle: .body)
        descriptionLabel.numberOfLines = 0
        descriptionLabel.accessibilityIdentifier = "repoDetails.descriptionLabel"

        languageTitleLabel.font = .preferredFont(forTextStyle: .caption1)
        languageTitleLabel.textColor = .secondaryLabel
        languageTitleLabel.text = "Language"

        languageValueLabel.font = .preferredFont(forTextStyle: .body)
        languageValueLabel.numberOfLines = 0
        languageValueLabel.accessibilityIdentifier = "repoDetails.languageValueLabel"

        starsTitleLabel.font = .preferredFont(forTextStyle: .caption1)
        starsTitleLabel.textColor = .secondaryLabel
        starsTitleLabel.text = "Stars"

        starsValueLabel.font = .preferredFont(forTextStyle: .body)
        starsValueLabel.numberOfLines = 0
        starsValueLabel.accessibilityIdentifier = "repoDetails.starsValueLabel"

        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .medium
        configuration.baseBackgroundColor = .systemBlue
        configuration.baseForegroundColor = .white
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        openOnGitHubButton.configuration = configuration
        openOnGitHubButton.accessibilityIdentifier = "repoDetails.openOnGitHubButton"
        openOnGitHubButton.accessibilityHint = "Opens the repository in GitHub."
    }

    private func setupBindings() {
        let input = RepoDetailsViewModel.Input(
            openOnGitHubTapped: openOnGitHubButton.rx.tap.asSignal()
        )

        let output = viewModel.transform(input: input)

        output.state
            .drive(rx.state)
            .disposed(by: disposeBag)

        output.openRepoURL
            .emit(onNext: { [weak self] url in
                guard let self else { return }
                let safariViewController = SFSafariViewController(url: url)
                self.present(safariViewController, animated: true)
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - Rx Bindings
private extension Reactive where Base: RepoDetailsViewController {

    var state: Binder<RepoDetailsViewModel.State> {
        Binder(base) { viewController, state in
            viewController.titleLabel.text = state.title
            viewController.subtitleLabel.text = state.subtitle
            viewController.subtitleLabel.textColor = state.subtitleIsSecondary ? .tertiaryLabel : .secondaryLabel

            viewController.descriptionLabel.text = state.descriptionText
            viewController.descriptionLabel.textColor = state.descriptionIsSecondary ? .secondaryLabel : .label

            viewController.languageValueLabel.text = state.languageText
            viewController.languageValueLabel.textColor = state.languageIsSecondary ? .secondaryLabel : .label

            viewController.starsValueLabel.text = state.starsText
            viewController.starsValueLabel.textColor = state.starsIsSecondary ? .secondaryLabel : .label

            viewController.openOnGitHubButton.configuration?.title = state.openButtonTitle
        }
    }
}
