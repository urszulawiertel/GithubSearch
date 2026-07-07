//
//  GitHubAPI.swift
//  GithubSearch
//
//  Created by Ula on 17/02/2026.
//

import Foundation

enum GitHubAPI {
    static func reposURL(
        username: String,
        page: Int = 1,
        perPage: Int = 50,
        sort: SearchSort = .bestMatch
    ) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.github.com"
        components.path = "/users/\(username)/repos"
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]

        if let sortValue = sort.apiValue {
            queryItems.append(URLQueryItem(name: "sort", value: sortValue))
        }

        components.queryItems = queryItems
        return components.url
    }

    static func languagesURL(owner: String, repo: String) -> URL? {
        repoURL(owner: owner, repo: repo, suffix: "languages")
    }

    static func readmeURL(owner: String, repo: String) -> URL? {
        repoURL(owner: owner, repo: repo, suffix: "readme")
    }

    static func latestReleaseURL(owner: String, repo: String) -> URL? {
        repoURL(owner: owner, repo: repo, suffix: "releases/latest")
    }

    private static func repoURL(owner: String, repo: String, suffix: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.github.com"
        components.path = "/repos/\(owner)/\(repo)/\(suffix)"
        return components.url
    }
}
