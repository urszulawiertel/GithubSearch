//
//  Coordinator.swift
//  GithubSearch
//
//  Created by Ula on 19/02/2026.
//

import UIKit

protocol Coordinator: AnyObject {
    func start()
}

class NavigationCoordinator: Coordinator {
    let navigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() { }
}
