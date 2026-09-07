//
//  RepositoryInsights.swift
//  GithubSearch
//

import Foundation

struct RepositoryInsightsContext: Equatable {
    struct Release: Equatable {
        let name: String
        let tagName: String
        let publishedAt: Date?
        let notesExcerpt: String?
    }

    let repositoryName: String
    let fullName: String
    let description: String?
    let primaryLanguage: String?
    let topics: [String]
    let starCount: Int
    let licenseName: String?
    let readmeExcerpt: String?
    let latestRelease: Release?

    var hasSufficientData: Bool {
        description != nil ||
            primaryLanguage != nil ||
            !topics.isEmpty ||
            readmeExcerpt != nil ||
            latestRelease != nil
    }
}

struct RepositoryInsights: Equatable {
    let overview: String
    let usefulFor: [String]
    let nextSteps: [String]
    let questionsToExplore: [String]
}

enum RepositoryInsightsState: Equatable {
    case idle
    case loading
    case loaded(RepositoryInsights)
    case insufficientData
    case failed
}
