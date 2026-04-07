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

    private enum Constants {
        static let contentInset: CGFloat = 16
        static let avatarSize: CGFloat = 56
        static let avatarCornerRadius: CGFloat = 12
    }

    private let disposeBag = DisposeBag()
    private let viewModel: RepoDetailsViewModel
    private let imageLoader: ImageLoading
    private var avatarTask: ImageLoadingTask?
    private var currentAvatarURL: URL?
    var onFinish: (() -> Void)?

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let headerView = UIView()
    private let avatarImageView = UIImageView()

    fileprivate let titleLabel = UILabel()
    fileprivate let subtitleLabel = UILabel()
    fileprivate let descriptionLabel = UILabel()

    fileprivate let languageTitleLabel = UILabel()
    fileprivate let languageValueLabel = UILabel()

    private let starsTitleLabel = UILabel()
    fileprivate let starsValueLabel = UILabel()

    fileprivate let openOnGitHubButton = UIButton(type: .system)

    // MARK: - Init

    init(viewModel: RepoDetailsViewModel, imageLoader: ImageLoading = ImageLoader.shared) {
        self.viewModel = viewModel
        self.imageLoader = imageLoader
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

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isMovingFromParent || isBeingDismissed {
            onFinish?()
        }
    }

    deinit {
        avatarTask?.cancel()
    }

    // MARK: - Setup

    private func setupHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(headerView)
        headerView.addSubview(avatarImageView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
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

        setupHeaderLayout()

        descriptionLabel.snp.makeConstraints {
            $0.top.equalTo(headerView.snp.bottom).offset(12)
            $0.leading.trailing.equalToSuperview().inset(Constants.contentInset)
        }

        setupMetadataLayout()
    }

    private func setupHeaderLayout() {
        headerView.snp.makeConstraints {
            $0.top.equalToSuperview().inset(Constants.contentInset)
            $0.leading.trailing.equalToSuperview().inset(Constants.contentInset)
        }

        avatarImageView.snp.makeConstraints {
            $0.top.leading.bottom.equalToSuperview()
            $0.size.equalTo(Constants.avatarSize)
        }

        titleLabel.snp.makeConstraints {
            $0.top.equalTo(headerView)
            $0.leading.equalTo(avatarImageView.snp.trailing).offset(12)
            $0.trailing.equalToSuperview()
        }

        subtitleLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(6)
            $0.leading.trailing.equalTo(titleLabel)
            $0.bottom.lessThanOrEqualToSuperview()
        }
    }

    private func setupMetadataLayout() {
        languageTitleLabel.snp.makeConstraints {
            $0.top.equalTo(descriptionLabel.snp.bottom).offset(16)
            $0.leading.equalToSuperview().inset(Constants.contentInset)
        }

        languageValueLabel.snp.makeConstraints {
            $0.centerY.equalTo(languageTitleLabel)
            $0.leading.equalTo(languageTitleLabel.snp.trailing).offset(8)
            $0.trailing.lessThanOrEqualToSuperview().inset(Constants.contentInset)
        }

        starsTitleLabel.snp.makeConstraints {
            $0.top.equalTo(languageTitleLabel.snp.bottom).offset(10)
            $0.leading.equalToSuperview().inset(Constants.contentInset)
        }

        starsValueLabel.snp.makeConstraints {
            $0.centerY.equalTo(starsTitleLabel)
            $0.leading.equalTo(starsTitleLabel.snp.trailing).offset(8)
            $0.trailing.lessThanOrEqualToSuperview().inset(Constants.contentInset)
        }

        openOnGitHubButton.snp.makeConstraints {
            $0.top.equalTo(starsTitleLabel.snp.bottom).offset(18)
            $0.leading.trailing.equalToSuperview().inset(Constants.contentInset)
            $0.height.equalTo(48)
            $0.bottom.equalToSuperview().inset(20)
        }
    }

    private func setupStyles() {
        avatarImageView.backgroundColor = .secondarySystemBackground
        avatarImageView.layer.cornerRadius = Constants.avatarCornerRadius
        avatarImageView.clipsToBounds = true
        avatarImageView.tintColor = .tertiaryLabel
        avatarImageView.isAccessibilityElement = true
        setAvatarPlaceholder()
        avatarImageView.accessibilityIdentifier = "repoDetails.avatarImageView"

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
        languageTitleLabel.text = L10n.RepoDetails.languageTitle

        languageValueLabel.font = .preferredFont(forTextStyle: .body)
        languageValueLabel.numberOfLines = 0
        languageValueLabel.accessibilityIdentifier = "repoDetails.languageValueLabel"

        starsTitleLabel.font = .preferredFont(forTextStyle: .caption1)
        starsTitleLabel.textColor = .secondaryLabel
        starsTitleLabel.text = L10n.RepoDetails.starsTitle

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
        openOnGitHubButton.accessibilityHint = L10n.RepoDetails.openButtonHint
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

    fileprivate func updateAvatarImage(with url: URL?, accessibilityLabel: String) {
        avatarImageView.accessibilityLabel = accessibilityLabel

        guard currentAvatarURL != url else { return }

        avatarTask?.cancel()
        avatarTask = nil
        currentAvatarURL = url
        setAvatarPlaceholder()

        guard let url else { return }

        avatarTask = imageLoader.loadImage(from: url) { [weak self] image in
            guard let self, self.currentAvatarURL == url else { return }

            defer { self.avatarTask = nil }

            guard let image else {
                self.setAvatarPlaceholder()
                return
            }

            AvatarImagePresenter.applyLoadedImage(image, to: self.avatarImageView)
        }
    }

    private func setAvatarPlaceholder() {
        AvatarImagePresenter.applyPlaceholder(
            to: avatarImageView,
            symbolName: "person.crop.square",
            pointSize: 28,
            weight: .regular
        )
    }

}

// MARK: - Rx Bindings
private extension Reactive where Base: RepoDetailsViewController {

    var state: Binder<RepoDetailsViewModel.State> {
        Binder(base) { viewController, state in
            viewController.titleLabel.text = state.title
            viewController.subtitleLabel.text = state.subtitle
            viewController.subtitleLabel.textColor = state.subtitleIsSecondary ? .tertiaryLabel : .secondaryLabel
            viewController.updateAvatarImage(
                with: state.avatarURL,
                accessibilityLabel: state.avatarAccessibilityLabel
            )

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
