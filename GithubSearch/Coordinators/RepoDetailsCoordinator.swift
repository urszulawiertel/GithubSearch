//
//  RepoDetailsCoordinator.swift
//  GithubSearch
//
//  Created by Ula on 19/02/2026.
//

import UIKit

final class RepoDetailsCoordinator: NavigationCoordinator {

    private let repo: Repo
    private let githubService: GitHubServiceType
    private let repositoryInsightsService: RepositoryInsightsServicing
    var onFinish: (() -> Void)?

    init(
        navigationController: UINavigationController,
        repo: Repo,
        githubService: GitHubServiceType,
        repositoryInsightsService: RepositoryInsightsServicing
    ) {
        self.repo = repo
        self.githubService = githubService
        self.repositoryInsightsService = repositoryInsightsService
        super.init(navigationController: navigationController)
    }

    override func start() {
        let viewModel = RepoDetailsViewModel(
            repo: repo,
            service: githubService,
            insightsService: repositoryInsightsService
        )
        let viewController = RepoDetailsViewController(viewModel: viewModel)
        viewController.onFinish = { [weak self] in
            self?.onFinish?()
        }
        navigationController.pushViewController(viewController, animated: true)
    }
}
