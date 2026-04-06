//
//  RepositoryCellTests.swift
//  GithubSearchTests
//
//  Created by Ula on 06/04/2026.
//

import XCTest
import UIKit
@testable import GithubSearch

final class RepositoryCellTests: XCTestCase {

    func test_configure_startsAvatarLoadForOwnerURL() {
        let imageLoader = ImageLoaderSpy()
        let cell = RepositoryCell(imageLoader: imageLoader)
        let repo = Repo.mock(owner: .init(login: "owner", avatarUrl: URL(string: "https://example.com/1.png")))

        cell.configure(with: repo)

        XCTAssertEqual(imageLoader.loadedURLs, [URL(string: "https://example.com/1.png")!])
        XCTAssertEqual(cell.avatarContentMode, .center)
    }

    func test_prepareForReuse_cancelsAvatarLoadAndRestoresPlaceholder() {
        let imageLoader = ImageLoaderSpy()
        let cell = RepositoryCell(imageLoader: imageLoader)
        let repo = Repo.mock(owner: .init(login: "owner", avatarUrl: URL(string: "https://example.com/1.png")))

        cell.configure(with: repo)
        let placeholderImage = cell.displayedAvatarImage

        cell.prepareForReuse()

        XCTAssertEqual(imageLoader.cancelledURLs, [URL(string: "https://example.com/1.png")!])
        XCTAssertEqual(cell.avatarContentMode, .center)
        XCTAssertTrue(cell.displayedAvatarImage === placeholderImage)
    }

    func test_oldAvatarCompletionIsIgnoredAfterCellIsReconfigured() {
        let imageLoader = ImageLoaderSpy()
        let cell = RepositoryCell(imageLoader: imageLoader)
        let firstURL = URL(string: "https://example.com/1.png")!
        let secondURL = URL(string: "https://example.com/2.png")!

        cell.configure(with: Repo.mock(id: 1, owner: .init(login: "owner", avatarUrl: firstURL)))
        cell.configure(with: Repo.mock(id: 2, owner: .init(login: "owner", avatarUrl: secondURL)))

        let secondImage = makeImage(color: .systemBlue)
        imageLoader.completeLoad(for: firstURL, with: makeImage(color: .systemRed))
        imageLoader.completeLoad(for: secondURL, with: secondImage)

        XCTAssertTrue(cell.displayedAvatarImage === secondImage)
        XCTAssertEqual(cell.avatarContentMode, .scaleAspectFill)
        XCTAssertEqual(imageLoader.cancelledURLs, [firstURL])
    }

    func test_configure_doesNotRestartAvatarLoadForSameURL() {
        let imageLoader = ImageLoaderSpy()
        let cell = RepositoryCell(imageLoader: imageLoader)
        let url = URL(string: "https://example.com/1.png")!
        let repo = Repo.mock(id: 1, owner: .init(login: "owner", avatarUrl: url))

        cell.configure(with: repo)
        cell.configure(with: repo)

        XCTAssertEqual(imageLoader.loadedURLs, [url])
        XCTAssertTrue(imageLoader.cancelledURLs.isEmpty)
    }

    private func makeImage(color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }
}

private final class ImageLoaderSpy: ImageLoading {
    private var completions: [URL: (UIImage?) -> Void] = [:]

    private(set) var loadedURLs: [URL] = []
    private(set) var cancelledURLs: [URL] = []

    @discardableResult
    func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) -> ImageLoadingTask {
        loadedURLs.append(url)
        completions[url] = completion
        return Task { [weak self] in
            self?.cancelledURLs.append(url)
            self?.completions[url] = nil
        }
    }

    func completeLoad(for url: URL, with image: UIImage?) {
        completions[url]?(image)
    }
}

private struct Task: ImageLoadingTask {
    let onCancel: () -> Void

    func cancel() {
        onCancel()
    }
}
