//
//  RepositoryInsightsServiceMock.swift
//  GithubSearchTests
//

import RxSwift
@testable import GithubSearch

final class RepositoryInsightsServiceMock: RepositoryInsightsServicing {
    private(set) var requestedContexts: [RepositoryInsightsContext] = []
    var handler: ((RepositoryInsightsContext) -> Single<RepositoryInsights>)?

    func generateInsights(for context: RepositoryInsightsContext) -> Single<RepositoryInsights> {
        requestedContexts.append(context)
        return handler?(context) ?? .error(RepositoryInsightsServiceError.server)
    }
}
