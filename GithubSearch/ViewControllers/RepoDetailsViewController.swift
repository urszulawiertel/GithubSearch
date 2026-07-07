//
//  RepoDetailsViewController.swift
//  GithubSearch
//
//  Created by Ula on 19/02/2026.
//

import UIKit
import RxSwift
import RxCocoa
import SafariServices

final class RepoDetailsViewController: UIViewController {

    private let detailsView = RepoDetailsView()
    private let disposeBag = DisposeBag()
    private let viewModel: RepoDetailsViewModel
    private let imageLoader: ImageLoading
    private var avatarTask: ImageLoadingTask?
    private var currentAvatarURL: URL?
    private let loadDetailsRelay = PublishRelay<Bool>()
    private let topicSelectedRelay = PublishRelay<String>()
    var onFinish: (() -> Void)?

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

    override func loadView() {
        view = detailsView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setAvatarPlaceholder()
        setupBindings()
        loadDetails(forceRefresh: false)
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

    private func setupBindings() {
        let input = RepoDetailsViewModel.Input(
            openOnGitHubTapped: detailsView.openOnGitHubButton.rx.tap.asSignal(),
            loadDetails: loadDetailsRelay.asSignal(),
            topicSelected: topicSelectedRelay.asSignal()
        )

        let output = viewModel.transform(input: input)

        detailsView.refreshControl.rx.controlEvent(.valueChanged)
            .subscribe(onNext: { [weak self] in
                self?.loadDetails(forceRefresh: true)
            })
            .disposed(by: disposeBag)

        detailsView.onTopicSelected = { [weak self] topic in
            self?.topicSelectedRelay.accept(topic)
        }

        output.state
            .drive(onNext: { [weak self] state in
                guard let self else { return }
                self.detailsView.render(state)
                self.updateAvatarImage(
                    with: state.avatarURL,
                    accessibilityLabel: state.avatarAccessibilityLabel
                )

                if !state.languagesSection.isLoading,
                   !state.readmeSection.isLoading,
                   !state.releaseSection.isLoading {
                    self.detailsView.endRefreshing()
                }
            })
            .disposed(by: disposeBag)

        output.openRepoURL
            .emit(onNext: { [weak self] url in
                guard let self else { return }
                let safariViewController = SFSafariViewController(url: url)
                self.present(safariViewController, animated: true)
            })
            .disposed(by: disposeBag)

        output.topicSelected
            .emit(onNext: { topic in
                // TODO: Route this through the coordinator when topic search is added to the app.
                _ = topic
            })
            .disposed(by: disposeBag)
    }

    private func loadDetails(forceRefresh: Bool) {
        loadDetailsRelay.accept(forceRefresh)
    }

    private func updateAvatarImage(with url: URL?, accessibilityLabel: String) {
        detailsView.avatarImageView.accessibilityLabel = accessibilityLabel

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

            AvatarImagePresenter.applyLoadedImage(image, to: self.detailsView.avatarImageView)
        }
    }

    private func setAvatarPlaceholder() {
        AvatarImagePresenter.applyPlaceholder(
            to: detailsView.avatarImageView,
            symbolName: "person.crop.square",
            pointSize: 28,
            weight: .regular
        )
    }
}
