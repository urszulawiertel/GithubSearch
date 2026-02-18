//
//  NetworkClient.swift
//  GithubSearch
//
//  Created by Ula on 17/02/2026.
//

import Foundation
import RxSwift

protocol NetworkClientType {
    func get(url: URL) -> Single<(HTTPURLResponse, Data)>
}

final class NetworkClient: NetworkClientType {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func get(url: URL) -> Single<(HTTPURLResponse, Data)> {
        return Single.create { [session] single in
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

            let task = session.dataTask(with: request) { data, response, error in
                if let error {
                    single(.failure(error))
                    return
                }
                guard let http = response as? HTTPURLResponse, let data else {
                    single(.failure(NSError(domain: "NetworkClient", code: -1)))
                    return
                }
                single(.success((http, data)))
            }

            task.resume()
            return Disposables.create { task.cancel() }
        }
    }
}
