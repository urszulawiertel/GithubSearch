//
//  NetworkClientMock.swift
//  GithubSearchTests
//
//  Created by Ula on 03/04/2026.
//

import Foundation
import RxSwift
@testable import GithubSearch

final class NetworkClientMock: NetworkClientType {

    var getCallCount = 0
    var lastURL: URL?
    var stubbedResult: Result<(HTTPURLResponse, Data), Error>?

    func get(url: URL) -> Single<(HTTPURLResponse, Data)> {
        getCallCount += 1
        lastURL = url

        switch stubbedResult {
        case let .success(response):
            return .just(response)
        case let .failure(error):
            return .error(error)
        case .none:
            return .error(GitHubServiceError.unknown)
        }
    }
}

extension HTTPURLResponse {
    static func mock(
        url: URL = URL(string: "https://api.github.com/users/octocat/repos")!,
        statusCode: Int
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}
