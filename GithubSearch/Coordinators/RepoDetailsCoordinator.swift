//
//  RepoDetailsCoordinator.swift
//  GithubSearch
//
//  Created by Ula on 19/02/2026.
//

import UIKit

final class RepoDetailsCoordinator: NavigationCoordinator {

    private let repo: Repo

    init(navigationController: UINavigationController, repo: Repo) {
        self.repo = repo
        super.init(navigationController: navigationController)
    }

    override func start() {
        let viewModel = RepoDetailsViewModel(repo: repo)
        let viewController = RepoDetailsViewController(viewModel: viewModel)
        navigationController.pushViewController(viewController, animated: true)
    }
}
