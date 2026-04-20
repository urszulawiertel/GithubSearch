//
//  SearchSort.swift
//  GithubSearch
//
//  Created by Ula on 20/04/2026.
//

import Foundation

enum SearchSort: CaseIterable, Equatable {
    case bestMatch
    case stars
    case updated
    case name

    var title: String {
        switch self {
        case .bestMatch:
            return L10n.Search.sortBestMatch
        case .stars:
            return L10n.Search.sortStars
        case .updated:
            return L10n.Search.sortUpdated
        case .name:
            return L10n.Search.sortName
        }
    }

    var apiValue: String? {
        switch self {
        case .bestMatch, .stars:
            return nil
        case .updated:
            return "updated"
        case .name:
            return "full_name"
        }
    }
}
