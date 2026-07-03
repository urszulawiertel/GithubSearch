//
//  ImageLoader.swift
//  GithubSearch
//
//  Created by Ula on 03/04/2026.
//

import Foundation
import UIKit

protocol ImageLoading: AnyObject {
    @discardableResult
    func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) -> ImageLoadingTask
}

protocol ImageLoadingTask {
    func cancel()
}

final class ImageLoader: ImageLoading {

    static let shared = ImageLoader()

    private let session: URLSession
    private let cache = NSCache<NSURL, UIImage>()
    private var inFlightRequests: [URL: InFlightRequest] = [:]
    private let lock = NSLock()

    init(session: URLSession = .shared) {
        self.session = session
    }

    #if DEBUG
    /// DEBUG-only hook used by the debug menu to clear the app's in-memory
    /// image cache. This API is compiled out of Release builds.
    func clearCache() {
        cache.removeAllObjects()
    }
    #endif

    @discardableResult
    func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) -> ImageLoadingTask {
        let token = TaskToken(completion: completion)

        if let cachedImage = cache.object(forKey: url as NSURL) {
            token.completeAsyncOnMain(with: cachedImage)
            return token
        }

        let requestID = UUID()
        var shouldStartRequest = false

        lock.lock()
        if var request = inFlightRequests[url] {
            request.completions[requestID] = token
            inFlightRequests[url] = request
        } else {
            inFlightRequests[url] = InFlightRequest(completions: [requestID: token], task: nil)
            shouldStartRequest = true
        }
        lock.unlock()

        if shouldStartRequest {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
            let task = session.dataTask(with: request) { [weak self] data, response, error in
                self?.handleResponse(for: url, data: data, response: response, error: error)
            }

            lock.lock()
            inFlightRequests[url]?.task = task
            lock.unlock()

            task.resume()
        }

        token.setOnCancel { [weak self] in
            self?.cancelLoad(for: url, requestID: requestID)
        }
        return token
    }

    private func handleResponse(for url: URL, data: Data?, response: URLResponse?, error: Error?) {
        let image = validatedImage(data: data, response: response, error: error)
        if let image {
            cache.setObject(image, forKey: url as NSURL)
        }

        let completions: [UUID: TaskToken]

        lock.lock()
        completions = inFlightRequests.removeValue(forKey: url)?.completions ?? [:]
        lock.unlock()

        DispatchQueue.main.async {
            completions.values.forEach { $0.completeOnMain(with: image) }
        }
    }

    private func validatedImage(data: Data?, response: URLResponse?, error: Error?) -> UIImage? {
        guard error == nil else { return nil }
        guard Self.supportsImageResponse(response) else { return nil }

        guard let data, !data.isEmpty else { return nil }
        return UIImage(data: data)
    }

    private func cancelLoad(for url: URL, requestID: UUID) {
        lock.lock()
        guard var request = inFlightRequests[url] else {
            lock.unlock()
            return
        }

        request.completions.removeValue(forKey: requestID)

        if request.completions.isEmpty {
            let task = request.task
            inFlightRequests.removeValue(forKey: url)
            lock.unlock()
            task?.cancel()
            return
        }

        inFlightRequests[url] = request
        lock.unlock()
    }

    static func supportsImageResponse(_ response: URLResponse?) -> Bool {
        if let mimeType = response?.mimeType?.lowercased(),
           !mimeType.isEmpty,
           !mimeType.hasPrefix("image/") {
            return false
        }

        if let httpResponse = response as? HTTPURLResponse {
            guard (200..<300).contains(httpResponse.statusCode) else {
                return false
            }

            if let mimeType = resolvedMIMEType(from: httpResponse),
               !mimeType.hasPrefix("image/") {
                return false
            }
        }

        return true
    }

    private static func resolvedMIMEType(from response: HTTPURLResponse) -> String? {
        if let mimeType = response.mimeType?.lowercased(), !mimeType.isEmpty {
            return mimeType
        }

        guard let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased() else {
            return nil
        }

        return contentType
            .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

private extension ImageLoader {
    struct InFlightRequest {
        var completions: [UUID: TaskToken]
        var task: URLSessionDataTask?
    }

    final class TaskToken: ImageLoadingTask {
        private let completion: (UIImage?) -> Void
        private let lock = NSLock()
        private var onCancel: (() -> Void)?
        private var isCancelled = false
        private var isCompleted = false

        init(completion: @escaping (UIImage?) -> Void) {
            self.completion = completion
        }

        func cancel() {
            let onCancel: (() -> Void)?

            lock.lock()
            guard !isCancelled, !isCompleted else {
                lock.unlock()
                return
            }
            isCancelled = true
            onCancel = self.onCancel
            self.onCancel = nil
            lock.unlock()

            onCancel?()
        }

        func setOnCancel(_ onCancel: @escaping () -> Void) {
            lock.lock()
            guard !isCancelled, !isCompleted else {
                lock.unlock()
                return
            }
            self.onCancel = onCancel
            lock.unlock()
        }

        func completeAsyncOnMain(with image: UIImage?) {
            DispatchQueue.main.async {
                self.completeOnMain(with: image)
            }
        }

        func completeOnMain(with image: UIImage?) {
            lock.lock()
            guard !isCancelled, !isCompleted else {
                lock.unlock()
                return
            }
            isCompleted = true
            onCancel = nil
            lock.unlock()

            completion(image)
        }
    }
}
