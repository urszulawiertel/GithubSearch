//
//  AppCoordinator.swift
//  GithubSearch
//
//  Created by Ula on 19/02/2026.
//

import UIKit

final class AppCoordinator: NavigationCoordinator {

    private var childCoordinators: [Coordinator] = []

    override func start() {
        let searchCoordinator = SearchCoordinator(navigationController: navigationController)
        childCoordinators.append(searchCoordinator)
        searchCoordinator.start()
    }
}
