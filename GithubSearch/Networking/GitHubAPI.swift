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
}
