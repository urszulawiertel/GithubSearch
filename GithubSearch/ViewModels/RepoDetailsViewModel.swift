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

    struct Output {
        let titleText: Driver<String>
        let subtitleText: Driver<String>
        let descriptionText: Driver<String?>
        let languageText: Driver<String?>
        let starsText: Driver<String>
        let openOnGitHubTitle: Driver<String>
        let openRepoURL: Signal<URL>
    }

    private let repo: Repo

    init(repo: Repo) {
        self.repo = repo
    }

    func transform(input: Input) -> Output {
        let titleText = Driver.just(repo.name)
        let subtitleText = Driver.just(repo.fullName)

        let descriptionText = Driver.just(repo.description)
        let languageText = Driver.just(repo.language)

        let starsText = Driver.just("★ \(repo.stargazersCount)")
        let openOnGitHubTitle = Driver.just("Open on GitHub")

        let openRepoURL = input.openOnGitHubTapped
            .map { [repo] in repo.htmlUrl }

        return Output(
            titleText: titleText,
            subtitleText: subtitleText,
            descriptionText: descriptionText,
            languageText: languageText,
            starsText: starsText,
            openOnGitHubTitle: openOnGitHubTitle,
            openRepoURL: openRepoURL
        )
    }
}
