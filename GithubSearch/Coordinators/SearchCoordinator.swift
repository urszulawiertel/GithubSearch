//
//  SearchCoordinator.swift
//  GithubSearch
//
//  Created by Ula on 19/02/2026.
//

import UIKit
import RxSwift
import RxCocoa

final class SearchCoordinator: NavigationCoordinator {

    private var childCoordinators: [Coordinator] = []
    private let disposeBag = DisposeBag()

    override func start() {
        let viewModel = SearchViewModel(service: AppLaunchEnvironment.makeGitHubService())
        let viewController = SearchViewController(viewModel: viewModel)

        viewController.onRepoSelected
            .subscribe(onNext: { [weak self] repo in
                self?.showRepoDetails(repo: repo)
            })
            .disposed(by: disposeBag)

        navigationController.setViewControllers([viewController], animated: false)
    }

    private func showRepoDetails(repo: Repo) {
        let coordinator = RepoDetailsCoordinator(
            navigationController: navigationController,
            repo: repo
        )
        coordinator.onFinish = { [weak self, weak coordinator] in
            guard let self, let coordinator else { return }
            self.removeChildCoordinator(coordinator)
        }
        childCoordinators.append(coordinator)
        coordinator.start()
    }

    private func removeChildCoordinator(_ coordinator: Coordinator) {
        childCoordinators.removeAll { $0 === coordinator }
    }
}
