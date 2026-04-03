//
//  Repo.swift
//  GithubSearch
//
//  Created by Ula on 17/02/2026.
//

import Foundation

struct RepoOwner: Decodable, Equatable {
    let avatarUrl: URL?

    enum CodingKeys: String, CodingKey {
        case avatarUrl = "avatar_url"
    }
}

struct Repo: Decodable, Equatable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let stargazersCount: Int
    let language: String?
    let htmlUrl: URL
    let owner: RepoOwner?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case description
        case stargazersCount = "stargazers_count"
        case language
        case htmlUrl = "html_url"
        case owner
    }
}
