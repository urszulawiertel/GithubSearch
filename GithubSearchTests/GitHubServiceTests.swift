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
        let url = try XCTUnwrap(GitHubAPI.reposURL(username: "octocat", page: 2, perPage: 25))
        let data = Data("""
        [
          {
            "id": 1,
            "name": "Hello-World",
            "full_name": "octocat/Hello-World",
            "description": "Example repository",
            "stargazers_count": 42,
            "language": "Swift",
            "html_url": "https://github.com/octocat/Hello-World",
            "owner": {
              "login": "octocat",
              "avatar_url": "https://avatars.githubusercontent.com/u/583231?v=4"
            }
          }
        ]
        """.utf8)
        client.stubbedResult = .success((.mock(url: url, statusCode: 200, headerFields: [
            "Link": #"<https://api.github.com/users/octocat/repos?page=3&per_page=25>; rel="next""#
        ]), data))

        let page = try service.fetchRepos(username: " octocat ", page: 2, perPage: 25)
            .toBlocking(timeout: 1)
            .single()

        XCTAssertEqual(client.getCallCount, 1)
        XCTAssertEqual(client.lastURL, url)
        XCTAssertEqual(page, RepoPage(
            repos: [
                Repo.mock(
                    id: 1,
                    name: "Hello-World",
                    fullName: "octocat/Hello-World",
                    description: "Example repository",
                    stargazersCount: 42,
                    language: "Swift",
                    htmlUrl: URL(string: "https://github.com/octocat/Hello-World")!,
                    owner: RepoOwner(login: "octocat", avatarUrl: URL(string: "https://avatars.githubusercontent.com/u/583231?v=4"))
                )
            ],
            hasNextPage: true
        ))
    }

    func test_fetchRepos_returnsDecodingErrorForInvalidPayload() {
        let client = NetworkClientMock()
        let service = GitHubService(client: client)
        let data = Data(#"{"unexpected":true}"#.utf8)
        client.stubbedResult = .success((.mock(statusCode: 200), data))

        XCTAssertThrowsError(
            try service.fetchRepos(username: "octocat", page: 1, perPage: 50)
                .toBlocking(timeout: 1)
                .single()
        ) { error in
            XCTAssertEqual(error as? GitHubServiceError, .decoding)
        }
    }

    func test_fetchRepos_marksNoNextPageWhenLinkHeaderIsMissing() throws {
        let client = NetworkClientMock()
        let service = GitHubService(client: client)
        let data = Data("[]".utf8)
        client.stubbedResult = .success((.mock(statusCode: 200), data))

        let page = try service.fetchRepos(username: "octocat", page: 1, perPage: 50)
            .toBlocking(timeout: 1)
            .single()

        XCTAssertFalse(page.hasNextPage)
    }

    func test_fetchRepos_maps404ToUserNotFound() {
        let client = NetworkClientMock()
        let service = GitHubService(client: client)
        client.stubbedResult = .success((.mock(statusCode: 404), Data()))

        XCTAssertThrowsError(
            try service.fetchRepos(username: "missing-user", page: 1, perPage: 50)
                .toBlocking(timeout: 1)
                .single()
        ) { error in
            XCTAssertEqual(error as? GitHubServiceError, .userNotFound)
        }
    }

    func test_fetchRepos_maps403ToRateLimited() {
        let client = NetworkClientMock()
        let service = GitHubService(client: client)
        client.stubbedResult = .success((.mock(statusCode: 403), Data()))

        XCTAssertThrowsError(
            try service.fetchRepos(username: "octocat", page: 1, perPage: 50)
                .toBlocking(timeout: 1)
                .single()
        ) { error in
            XCTAssertEqual(error as? GitHubServiceError, .rateLimited)
        }
    }

    func test_fetchRepos_mapsConnectivityErrors() {
        let client = NetworkClientMock()
        let service = GitHubService(client: client)
        client.stubbedResult = .failure(URLError(.notConnectedToInternet))

        XCTAssertThrowsError(
            try service.fetchRepos(username: "octocat", page: 1, perPage: 50)
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
            try service.fetchRepos(username: "octocat", page: 1, perPage: 50)
                .toBlocking(timeout: 1)
                .single()
        ) { error in
            XCTAssertEqual(error as? GitHubServiceError, .unknown)
        }
    }

    func test_fetchRepos_marksNoNextPageWhenLinkHeaderHasNoNextRelation() throws {
        let client = NetworkClientMock()
        let service = GitHubService(client: client)
        let data = Data("[]".utf8)
        client.stubbedResult = .success((.mock(statusCode: 200, headerFields: [
            "Link": #"<https://api.github.com/users/octocat/repos?page=2&per_page=50>; rel="last""#
        ]), data))

        let page = try service.fetchRepos(username: "octocat", page: 1, perPage: 50)
            .toBlocking(timeout: 1)
            .single()

        XCTAssertFalse(page.hasNextPage)
    }

    func test_fetchLanguages_decodesAndSortsLanguagePercentages() throws {
        let client = NetworkClientMock()
        let service = GitHubService(client: client)
        let url = try XCTUnwrap(GitHubAPI.languagesURL(owner: "octocat", repo: "Hello-World"))
        client.stubbedResult = .success((.mock(url: url, statusCode: 200), Data("""
        {
          "Swift": 300,
          "Ruby": 100
        }
        """.utf8)))

        let languages = try service.fetchLanguages(owner: "octocat", repo: "Hello-World")
            .toBlocking(timeout: 1)
            .single()

        XCTAssertEqual(client.lastURL, url)
        XCTAssertEqual(languages, [
            RepositoryLanguage(name: "Swift", bytes: 300, percentage: 75),
            RepositoryLanguage(name: "Ruby", bytes: 100, percentage: 25)
        ])
    }

    func test_fetchLanguages_returnsCachedValueOnSecondRequest() throws {
        let client = NetworkClientMock()
        let service = GitHubService(client: client)
        client.stubbedResult = .success((.mock(statusCode: 200), Data(#"{"Swift":100}"#.utf8)))

        _ = try service.fetchLanguages(owner: "octocat", repo: "Hello-World")
            .toBlocking(timeout: 1)
            .single()
        _ = try service.fetchLanguages(owner: "octocat", repo: "Hello-World")
            .toBlocking(timeout: 1)
            .single()

        XCTAssertEqual(client.getCallCount, 1)
    }

    func test_fetchLanguages_forceRefreshBypassesCache() throws {
        let client = NetworkClientMock()
        let service = GitHubService(client: client)
        client.stubbedResult = .success((.mock(statusCode: 200), Data(#"{"Swift":100}"#.utf8)))

        _ = try service.fetchLanguages(owner: "octocat", repo: "Hello-World")
            .toBlocking(timeout: 1)
            .single()
        _ = try service.fetchLanguages(owner: "octocat", repo: "Hello-World", forceRefresh: true)
            .toBlocking(timeout: 1)
            .single()

        XCTAssertEqual(client.getCallCount, 2)
    }

    func test_fetchReadme_decodesBase64Content() throws {
        let client = NetworkClientMock()
        let service = GitHubService(client: client)
        let content = Data("# Hello\n\nREADME body".utf8).base64EncodedString()
        client.stubbedResult = .success((.mock(statusCode: 200), Data("""
        {
          "content": "\(content)",
          "encoding": "base64"
        }
        """.utf8)))

        let readme = try service.fetchReadme(owner: "octocat", repo: "Hello-World")
            .toBlocking(timeout: 1)
            .single()

        XCTAssertEqual(readme, RepositoryReadme(text: "# Hello\n\nREADME body"))
    }

    func test_fetchReadme_returnsCachedValueOnSecondRequest() throws {
        let client = NetworkClientMock()
        let service = GitHubService(client: client)
        let content = Data("README body".utf8).base64EncodedString()
        client.stubbedResult = .success((.mock(statusCode: 200), Data("""
        {
          "content": "\(content)",
          "encoding": "base64"
        }
        """.utf8)))

        _ = try service.fetchReadme(owner: "octocat", repo: "Hello-World")
            .toBlocking(timeout: 1)
            .single()
        _ = try service.fetchReadme(owner: "octocat", repo: "Hello-World")
            .toBlocking(timeout: 1)
            .single()

        XCTAssertEqual(client.getCallCount, 1)
    }

    func test_fetchReadme_returnsNilFor404() throws {
        let client = NetworkClientMock()
        let service = GitHubService(client: client)
        client.stubbedResult = .success((.mock(statusCode: 404), Data()))

        let readme = try service.fetchReadme(owner: "octocat", repo: "Hello-World")
            .toBlocking(timeout: 1)
            .single()

        XCTAssertNil(readme)
    }

    func test_fetchLatestRelease_decodesRelease() throws {
        let client = NetworkClientMock()
        let service = GitHubService(client: client)
        client.stubbedResult = .success((.mock(statusCode: 200), Data("""
        {
          "name": "Version 1.0",
          "tag_name": "v1.0",
          "published_at": "2026-04-05T10:00:00Z",
          "body": "Release notes"
        }
        """.utf8)))

        let release = try service.fetchLatestRelease(owner: "octocat", repo: "Hello-World")
            .toBlocking(timeout: 1)
            .single()

        XCTAssertEqual(release, RepositoryRelease(
            name: "Version 1.0",
            tagName: "v1.0",
            publishedAt: GitHubDateParser.date(from: "2026-04-05T10:00:00Z"),
            body: "Release notes"
        ))
    }

    func test_fetchLatestRelease_returnsNilFor404() throws {
        let client = NetworkClientMock()
        let service = GitHubService(client: client)
        client.stubbedResult = .success((.mock(statusCode: 404), Data()))

        let release = try service.fetchLatestRelease(owner: "octocat", repo: "Hello-World")
            .toBlocking(timeout: 1)
            .single()

        XCTAssertNil(release)
    }
}
