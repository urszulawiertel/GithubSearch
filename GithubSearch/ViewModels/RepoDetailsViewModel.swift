//
//  RepoDetailsViewModel.swift
//  GithubSearch
//
//  Created by Ula on 19/02/2026.
//

import Foundation
import RxSwift
import RxCocoa

final class RepoDetailsViewModel {

    struct Input {
        let openOnGitHubTapped: Signal<Void>
    }

    struct State: Equatable {
        let title: String
        let subtitle: String
        let descriptionText: String
        let descriptionIsSecondary: Bool
        let languageText: String
        let languageIsSecondary: Bool
        let starsText: String
        let openButtonTitle: String
    }

    struct Output {
        let state: Driver<State>
        let openRepoURL: Signal<URL>
    }

    private let repo: Repo

    init(repo: Repo) {
        self.repo = repo
    }

    func transform(input: Input) -> Output {
        let state = State(
            title: repo.name,
            subtitle: repo.fullName,
            descriptionText: repo.description ?? "No description",
            descriptionIsSecondary: repo.description == nil,
            languageText: repo.language ?? "—",
            languageIsSecondary: repo.language == nil,
            starsText: "★ \(repo.stargazersCount)",
            openButtonTitle: "Open on GitHub"
        )

        let openRepoURL = input.openOnGitHubTapped
            .map { [repo] in repo.htmlUrl }

        return Output(
            state: Driver.just(state),
            openRepoURL: openRepoURL
        )
    }
}
