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
        perPage: Int = 50
    ) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.github.com"
        components.path = "/users/\(username)/repos"
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage)),
            URLQueryItem(name: "sort", value: "updated")
        ]
        return components.url
    }
}
