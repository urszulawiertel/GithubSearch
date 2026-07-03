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

        #if DEBUG
        // DEBUG-only route to the debug menu. This subscription and destination
        // view controller are removed from Release builds by the compiler.
        viewController.onDebugSelected
            .subscribe(onNext: { [weak self] in
                self?.showDebugMenu()
            })
            .disposed(by: disposeBag)
        #endif

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

    #if DEBUG
    private func showDebugMenu() {
        navigationController.pushViewController(DebugViewController(), animated: true)
    }
    #endif
}
