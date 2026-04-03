//
//  GitHubServiceTests.swift
//  GithubSearchTests
//
//  Created by Ula on 03/04/2026.
//

import XCTest
import RxBlocking
@testable import GithubSearch

final class GitHubServiceTests: XCTestCase {

    func test_fetchRepos_decodesRepositoriesOnSuccessfulResponse() throws {
        let client = NetworkClientMock()
        let service = GitHubService(client: client)
        let url = try XCTUnwrap(GitHubAPI.reposURL(username: "octocat"))
        let data = """
        [
          {
            "id": 1,
            "name": "Hello-World",
            "full_name": "octocat/Hello-World",
            "description": "Example repository",
            "stargazers_count": 42,
            "language": "Swift",
            "html_url": "https://github.com/octocat/Hello-World"
          }
        ]
        """.data(using: .utf8)!
        client.stubbedResult = .success((.mock(url: url, statusCode: 200), data))

        let repos = try service.fetchRepos(username: " octocat ")
            .toBlocking(timeout: 1)
            .single()

        XCTAssertEqual(client.getCallCount, 1)
        XCTAssertEqual(client.lastURL, url)
        XCTAssertEqual(repos, [
            Repo.mock(
                id: 1,
                name: "Hello-World",
                fullName: "octocat/Hello-World",
                description: "Example repository",
                stargazersCount: 42,
                language: "Swift",
                htmlUrl: URL(string: "https://github.com/octocat/Hello-World")!
            )
        ])
    }

    func test_fetchRepos_returnsDecodingErrorForInvalidPayload() {
        let client = NetworkClientMock()
        let service = GitHubService(client: client)
        let data = #"{"unexpected":true}"#.data(using: .utf8)!
        client.stubbedResult = .success((.mock(statusCode: 200), data))

        XCTAssertThrowsError(
            try service.fetchRepos(username: "octocat")
                .toBlocking(timeout: 1)
                .single()
        ) { error in
            XCTAssertEqual(error as? GitHubServiceError, .decoding)
        }
    }

    func test_fetchRepos_maps404ToUserNotFound() {
        let client = NetworkClientMock()
        let service = GitHubService(client: client)
        client.stubbedResult = .success((.mock(statusCode: 404), Data()))

        XCTAssertThrowsError(
            try service.fetchRepos(username: "missing-user")
                .toBlocking(timeout: 1)
                .single()
        ) { error in
            XCTAssertEqual(error as? GitHubServiceError, .userNotFound)
        }
    }

    func test_fetchRepos_mapsConnectivityErrors() {
        let client = NetworkClientMock()
        let service = GitHubService(client: client)
        client.stubbedResult = .failure(URLError(.notConnectedToInternet))

        XCTAssertThrowsError(
            try service.fetchRepos(username: "octocat")
                .toBlocking(timeout: 1)
                .single()
        ) { error in
            XCTAssertEqual(error as? GitHubServiceError, .connectivity)
        }
    }

    func test_fetchRepos_mapsUnexpectedFailuresToUnknown() {
        let client = NetworkClientMock()
        let service = GitHubService(client: client)
        client.stubbedResult = .failure(URLError(.badServerResponse))

        XCTAssertThrowsError(
            try service.fetchRepos(username: "octocat")
                .toBlocking(timeout: 1)
                .single()
        ) { error in
            XCTAssertEqual(error as? GitHubServiceError, .unknown)
        }
    }
}
