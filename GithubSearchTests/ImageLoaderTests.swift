//
//  ImageLoaderTests.swift
//  GithubSearchTests
//
//  Created by Ula on 03/04/2026.
//

import XCTest
import UIKit
@testable import GithubSearch

final class ImageLoaderTests: XCTestCase {

    override func tearDown() {
        URLProtocolMock.requestHandler = nil
        URLProtocolMock.requestCount = 0
        super.tearDown()
    }

    func test_loadImage_returnsCachedImageWithoutStartingNewFetch() {
        let loader = makeLoader()
        let url = URL(string: "https://example.com/avatar.png")!
        let imageData = makeImageData()
        URLProtocolMock.requestHandler = { request in
            URLProtocolMock.requestCount += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (.success(response, imageData))
        }

        let firstLoad = expectation(description: "First image load")
        let secondLoad = expectation(description: "Second image load")

        loader.loadImage(from: url) { image in
            XCTAssertNotNil(image)
            firstLoad.fulfill()
        }

        wait(for: [firstLoad], timeout: 1)

        loader.loadImage(from: url) { image in
            XCTAssertNotNil(image)
            secondLoad.fulfill()
        }

        wait(for: [secondLoad], timeout: 1)
        XCTAssertEqual(URLProtocolMock.requestCount, 1)
    }

    func test_loadImage_deduplicatesConcurrentRequestsForSameURL() {
        let loader = makeLoader()
        let url = URL(string: "https://example.com/avatar.png")!
        let imageData = makeImageData()
        URLProtocolMock.requestHandler = { request in
            URLProtocolMock.requestCount += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (.delayedSuccess(response, imageData))
        }

        let firstCompletion = expectation(description: "First completion")
        let secondCompletion = expectation(description: "Second completion")

        loader.loadImage(from: url) { image in
            XCTAssertNotNil(image)
            firstCompletion.fulfill()
        }

        loader.loadImage(from: url) { image in
            XCTAssertNotNil(image)
            secondCompletion.fulfill()
        }

        wait(for: [firstCompletion, secondCompletion], timeout: 1)
        XCTAssertEqual(URLProtocolMock.requestCount, 1)
    }

    func test_loadImage_cancellationRemovesPendingCompletion() {
        let loader = makeLoader()
        let url = URL(string: "https://example.com/avatar.png")!
        let imageData = makeImageData()
        URLProtocolMock.requestHandler = { request in
            URLProtocolMock.requestCount += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (.delayedSuccess(response, imageData))
        }

        let cancelledCompletion = expectation(description: "Cancelled completion")
        cancelledCompletion.isInverted = true
        let activeCompletion = expectation(description: "Active completion")

        let task = loader.loadImage(from: url) { _ in
            cancelledCompletion.fulfill()
        }
        loader.loadImage(from: url) { image in
            XCTAssertNotNil(image)
            activeCompletion.fulfill()
        }

        task.cancel()

        wait(for: [activeCompletion], timeout: 1)
        wait(for: [cancelledCompletion], timeout: 0.1)
        XCTAssertEqual(URLProtocolMock.requestCount, 1)
    }

    func test_loadImage_returnsNilForNonSuccessfulHTTPResponse() {
        let loader = makeLoader()
        let url = URL(string: "https://example.com/avatar.png")!
        let imageData = makeImageData()
        URLProtocolMock.requestHandler = { request in
            URLProtocolMock.requestCount += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (.success(response, imageData))
        }

        let completion = expectation(description: "Image load completes with nil")

        loader.loadImage(from: url) { image in
            XCTAssertNil(image)
            completion.fulfill()
        }

        wait(for: [completion], timeout: 1)
        XCTAssertEqual(URLProtocolMock.requestCount, 1)
    }

    func test_loadImage_returnsNilForInvalidImageData() {
        let loader = makeLoader()
        let url = URL(string: "https://example.com/avatar.png")!
        let invalidData = Data("not an image".utf8)
        URLProtocolMock.requestHandler = { request in
            URLProtocolMock.requestCount += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (.success(response, invalidData))
        }

        let completion = expectation(description: "Image load completes with nil")

        loader.loadImage(from: url) { image in
            XCTAssertNil(image)
            completion.fulfill()
        }

        wait(for: [completion], timeout: 1)
        XCTAssertEqual(URLProtocolMock.requestCount, 1)
    }

    func test_supportsImageResponse_returnsFalseForNonImageMIMEType() {
        let response = URLResponse(
            url: URL(string: "https://example.com/avatar.png")!,
            mimeType: "text/plain",
            expectedContentLength: 4,
            textEncodingName: nil
        )

        XCTAssertFalse(ImageLoader.supportsImageResponse(response))
    }

    private func makeLoader() -> ImageLoader {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolMock.self]
        let session = URLSession(configuration: configuration)
        return ImageLoader(session: session)
    }

    private func makeImageData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2))
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        return image.pngData()!
    }
}

private final class URLProtocolMock: URLProtocol {

    enum StubbedResponse {
        case success(URLResponse, Data)
        case delayedSuccess(URLResponse, Data)
    }

    static var requestHandler: ((URLRequest) -> StubbedResponse)?
    static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            XCTFail("Missing request handler")
            return
        }

        switch handler(request) {
        case let .success(response, data):
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case let .delayedSuccess(response, data):
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self else { return }
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                self.client?.urlProtocol(self, didLoad: data)
                self.client?.urlProtocolDidFinishLoading(self)
            }
        }
    }

    override func stopLoading() {}
}
