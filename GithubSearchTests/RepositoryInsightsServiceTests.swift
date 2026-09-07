//
//  RepositoryInsightsServiceTests.swift
//  GithubSearchTests
//

import XCTest
import RxSwift
import RxBlocking
@testable import GithubSearch

final class RepositoryInsightsServiceTests: XCTestCase {
    private let endpoint = URL(string: "https://example.com/v1/repository-insights")!

    func test_requestContainsExpectedRepositoryContextAndSafetyInstructions() throws {
        let client = RepositoryInsightsHTTPClientMock()
        client.result = .success((.mock(url: endpoint, statusCode: 200), Self.validResponseData))
        let service = RepositoryInsightsProxyService(endpoint: endpoint, client: client)
        let context = Self.makeContext()

        _ = try service.generateInsights(for: context).toBlocking().single()

        let request = try XCTUnwrap(client.lastRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let encodedContext = try XCTUnwrap(json["context"] as? [String: Any])
        XCTAssertEqual(encodedContext["repositoryName"] as? String, "GithubSearch")
        XCTAssertEqual(encodedContext["fullName"] as? String, "urszula/GithubSearch")
        XCTAssertEqual(encodedContext["description"] as? String, "Search GitHub repositories.")
        XCTAssertEqual(encodedContext["primaryLanguage"] as? String, "Swift")
        XCTAssertEqual(encodedContext["topics"] as? [String], ["ios", "rxswift"])
        XCTAssertEqual(encodedContext["starCount"] as? Int, 125)
        XCTAssertEqual(encodedContext["licenseName"] as? String, "MIT License")
        XCTAssertEqual(encodedContext["readmeExcerpt"] as? String, "README excerpt")
        XCTAssertEqual(json["repositoryContentIsUntrusted"] as? Bool, true)

        let instructions = try XCTUnwrap(json["instructions"] as? [String])
        XCTAssertTrue(instructions.contains { $0.localizedCaseInsensitiveContains("do not invent") })
        XCTAssertTrue(instructions.contains { $0.localizedCaseInsensitiveContains("untrusted") })
        XCTAssertTrue(instructions.contains { $0.localizedCaseInsensitiveContains("exactly three") })
    }

    func test_validStructuredResponseMapsToDomainModel() throws {
        let client = RepositoryInsightsHTTPClientMock()
        client.result = .success((.mock(url: endpoint, statusCode: 200), Self.validResponseData))
        let service = RepositoryInsightsProxyService(endpoint: endpoint, client: client)

        let insights = try service.generateInsights(for: Self.makeContext()).toBlocking().single()

        XCTAssertEqual(insights.overview, "A focused iOS repository search application.")
        XCTAssertEqual(insights.usefulFor, ["iOS developers", "MVVM learners"])
        XCTAssertEqual(insights.nextSteps, ["Run the app", "Read the architecture notes", "Review releases"])
        XCTAssertEqual(insights.questionsToExplore, ["How is pagination handled?"])
    }

    func test_malformedJSONProducesControlledDecodingError() {
        assertError(for: Data("not-json".utf8), equals: .decoding)
    }

    func test_missingRequiredFieldsProducesControlledDecodingError() {
        assertError(for: Data(#"{"overview":"Only one field"}"#.utf8), equals: .decoding)
    }

    func test_incompleteStructuredResponseProducesControlledValidationError() {
        let data = Data(#"{"overview":"Overview","usefulFor":["Developers"],"nextSteps":["Only one"],"questionsToExplore":["Why?"]}"#.utf8)
        assertError(for: data, equals: .invalidResponse)
    }

    func test_httpErrorMapsConsistently() {
        let client = RepositoryInsightsHTTPClientMock()
        client.result = .success((.mock(url: endpoint, statusCode: 503), Data()))
        let service = RepositoryInsightsProxyService(endpoint: endpoint, client: client)

        XCTAssertThrowsError(try service.generateInsights(for: Self.makeContext()).toBlocking().single()) { error in
            XCTAssertEqual(error as? RepositoryInsightsServiceError, .server)
        }
    }

    func test_connectivityErrorMapsConsistently() {
        let client = RepositoryInsightsHTTPClientMock()
        client.result = .failure(URLError(.notConnectedToInternet))
        let service = RepositoryInsightsProxyService(endpoint: endpoint, client: client)

        XCTAssertThrowsError(try service.generateInsights(for: Self.makeContext()).toBlocking().single()) { error in
            XCTAssertEqual(error as? RepositoryInsightsServiceError, .connectivity)
        }
    }

    func test_launchConfigurationSelectsExpectedInsightsService() {
        let bundle = Bundle(for: RepoDetailsViewModel.self)
        let proxy = AppLaunchEnvironment.makeRepositoryInsightsService(
            bundle: bundle, environment: ["REPOSITORY_INSIGHTS_MODE": "proxy"]
        )
        XCTAssertTrue(proxy is RepositoryInsightsProxyService)
        let defaultService = AppLaunchEnvironment.makeRepositoryInsightsService(bundle: bundle, environment: [:])
        #if DEBUG
        XCTAssertTrue(defaultService is DebugRepositoryInsightsService)
        #else
        XCTAssertTrue(defaultService is RepositoryInsightsProxyService)
        #endif
        XCTAssertEqual(
            bundle.object(forInfoDictionaryKey: "RepositoryInsightsProxyURL") as? String,
            "https://githubsearch-insights.moonshoka.workers.dev/api/repository-insights"
        )
    }

    func test_requestPreservesSchemaLocaleAndReleaseCodingKeys() throws {
        let builder = RepositoryInsightsRequestBuilder(locale: { Locale(identifier: "pl_PL") })
        let request = try builder.makeRequest(endpoint: endpoint, context: Self.makeContext())
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["schemaVersion"] as? Int, 1)
        XCTAssertEqual(json["locale"] as? String, "pl")
        let context = try XCTUnwrap(json["context"] as? [String: Any])
        let release = try XCTUnwrap(context["latestRelease"] as? [String: Any])
        XCTAssertEqual(release["tagName"] as? String, "v1.0")
        XCTAssertEqual(release["publishedAt"] as? String, "1970-01-01T00:00:00Z")
        XCTAssertEqual(release["notesExcerpt"] as? String, "Initial release")
    }

    func test_controlledBackendErrorsMapToRetryableServerError() {
        for status in [400, 413, 422, 429, 502, 503, 504] {
            let client = RepositoryInsightsHTTPClientMock()
            let data = Data(#"{"error":{"code":"unavailable","message":"Please retry."}}"#.utf8)
            client.result = .success((.mock(url: endpoint, statusCode: status), data))
            let service = RepositoryInsightsProxyService(endpoint: endpoint, client: client)
            XCTAssertThrowsError(try service.generateInsights(for: Self.makeContext()).toBlocking().single()) { error in
                XCTAssertEqual(error as? RepositoryInsightsServiceError, .server)
            }
        }
    }

    private func assertError(for data: Data, equals expectedError: RepositoryInsightsServiceError) {
        let client = RepositoryInsightsHTTPClientMock()
        client.result = .success((.mock(url: endpoint, statusCode: 200), data))
        let service = RepositoryInsightsProxyService(endpoint: endpoint, client: client)

        XCTAssertThrowsError(try service.generateInsights(for: Self.makeContext()).toBlocking().single()) { error in
            XCTAssertEqual(error as? RepositoryInsightsServiceError, expectedError)
        }
    }

    private static func makeContext() -> RepositoryInsightsContext {
        RepositoryInsightsContext(
            repositoryName: "GithubSearch",
            fullName: "urszula/GithubSearch",
            description: "Search GitHub repositories.",
            primaryLanguage: "Swift",
            topics: ["ios", "rxswift"],
            starCount: 125,
            licenseName: "MIT License",
            readmeExcerpt: "README excerpt",
            latestRelease: RepositoryInsightsContext.Release(
                name: "Version 1.0",
                tagName: "v1.0",
                publishedAt: Date(timeIntervalSince1970: 0),
                notesExcerpt: "Initial release"
            )
        )
    }

    private static let validResponseData = Data(#"{"overview":"A focused iOS repository search application.","usefulFor":["iOS developers","MVVM learners"],"nextSteps":["Run the app","Read the architecture notes","Review releases"],"questionsToExplore":["How is pagination handled?"]}"#.utf8)
}

private final class RepositoryInsightsHTTPClientMock: RepositoryInsightsHTTPClientType {
    private(set) var lastRequest: URLRequest?
    var result: Result<(HTTPURLResponse, Data), Error>?

    func execute(_ request: URLRequest) -> Single<(HTTPURLResponse, Data)> {
        lastRequest = request

        switch result {
        case let .success(value):
            return .just(value)
        case let .failure(error):
            return .error(error)
        case .none:
            return .error(RepositoryInsightsServiceError.server)
        }
    }
}
