//
//  Repo.swift
//  GithubSearch
//
//  Created by Ula on 17/02/2026.
//

import Foundation

struct RepoOwner: Decodable, Equatable {
    let login: String
    let avatarUrl: URL?

    enum CodingKeys: String, CodingKey {
        case login
        case avatarUrl = "avatar_url"
    }
}

struct RepoLicense: Decodable, Equatable {
    let name: String
    let spdxId: String?

    enum CodingKeys: String, CodingKey {
        case name
        case spdxId = "spdx_id"
    }
}

struct Repo: Decodable, Equatable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let stargazersCount: Int
    let forksCount: Int
    let openIssuesCount: Int
    let watchersCount: Int
    let language: String?
    let htmlUrl: URL
    let updatedAt: Date?
    let topics: [String]
    let defaultBranch: String?
    let license: RepoLicense?
    let owner: RepoOwner?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case description
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case openIssuesCount = "open_issues_count"
        case watchersCount = "watchers_count"
        case language
        case htmlUrl = "html_url"
        case updatedAt = "updated_at"
        case topics
        case defaultBranch = "default_branch"
        case license
        case owner
    }

    init(
        id: Int,
        name: String,
        fullName: String,
        description: String?,
        stargazersCount: Int,
        forksCount: Int = 0,
        openIssuesCount: Int = 0,
        watchersCount: Int = 0,
        language: String?,
        htmlUrl: URL,
        updatedAt: Date? = nil,
        topics: [String] = [],
        defaultBranch: String? = nil,
        license: RepoLicense? = nil,
        owner: RepoOwner?
    ) {
        self.id = id
        self.name = name
        self.fullName = fullName
        self.description = description
        self.stargazersCount = stargazersCount
        self.forksCount = forksCount
        self.openIssuesCount = openIssuesCount
        self.watchersCount = watchersCount
        self.language = language
        self.htmlUrl = htmlUrl
        self.updatedAt = updatedAt
        self.topics = topics
        self.defaultBranch = defaultBranch
        self.license = license
        self.owner = owner
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        fullName = try container.decode(String.self, forKey: .fullName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        stargazersCount = try container.decodeIfPresent(Int.self, forKey: .stargazersCount) ?? 0
        forksCount = try container.decodeIfPresent(Int.self, forKey: .forksCount) ?? 0
        openIssuesCount = try container.decodeIfPresent(Int.self, forKey: .openIssuesCount) ?? 0
        watchersCount = try container.decodeIfPresent(Int.self, forKey: .watchersCount) ?? 0
        language = try container.decodeIfPresent(String.self, forKey: .language)
        htmlUrl = try container.decode(URL.self, forKey: .htmlUrl)
        topics = try container.decodeIfPresent([String].self, forKey: .topics) ?? []
        defaultBranch = try container.decodeIfPresent(String.self, forKey: .defaultBranch)
        license = try container.decodeIfPresent(RepoLicense.self, forKey: .license)
        owner = try container.decodeIfPresent(RepoOwner.self, forKey: .owner)

        if let updatedAtString = try container.decodeIfPresent(String.self, forKey: .updatedAt) {
            updatedAt = GitHubDateParser.date(from: updatedAtString)
        } else {
            updatedAt = nil
        }
    }
}

struct RepositoryLanguage: Equatable {
    let name: String
    let bytes: Int
    let percentage: Double
}

struct RepositoryReadme: Equatable {
    let text: String
}

struct RepositoryRelease: Equatable {
    let name: String
    let tagName: String
    let publishedAt: Date?
    let body: String?
}

struct GitHubReadmeResponse: Decodable {
    let content: String
    let encoding: String
}

struct GitHubReleaseResponse: Decodable {
    let name: String?
    let tagName: String
    let publishedAt: Date?
    let body: String?

    enum CodingKeys: String, CodingKey {
        case name
        case tagName = "tag_name"
        case publishedAt = "published_at"
        case body
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        tagName = try container.decode(String.self, forKey: .tagName)
        body = try container.decodeIfPresent(String.self, forKey: .body)

        if let publishedAtString = try container.decodeIfPresent(String.self, forKey: .publishedAt) {
            publishedAt = GitHubDateParser.date(from: publishedAtString)
        } else {
            publishedAt = nil
        }
    }
}

enum GitHubDateParser {
    static func date(from string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)
    }
}
