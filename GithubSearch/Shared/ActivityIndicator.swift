//
//  ActivityIndicator.swift
//  GithubSearch
//
//  Created by Ula on 17/02/2026.
//

import Foundation
import RxSwift
import RxCocoa

public final class ActivityIndicator: SharedSequenceConvertibleType {
    public typealias Element = Bool
    public typealias SharingStrategy = DriverSharingStrategy

    private let lock = NSRecursiveLock()
    private let relay = BehaviorRelay<Int>(value: 0)
    private let loading: SharedSequence<SharingStrategy, Bool>

    public init() {
        loading = relay
            .asDriver()
            .map { $0 > 0 }
            .distinctUntilChanged()
    }

    fileprivate func track<O: ObservableConvertibleType>(_ source: O) -> Observable<O.Element> {
        return Observable.using({ () -> ActivityToken<O.Element> in
            self.increment()
            return ActivityToken(source: source.asObservable(), disposeAction: self.decrement)
        }, observableFactory: { token in
            token.asObservable()
        })
    }

    private func increment() {
        lock.lock(); defer { lock.unlock() }
        relay.accept(relay.value + 1)
    }

    private func decrement() {
        lock.lock(); defer { lock.unlock() }
        relay.accept(max(relay.value - 1, 0))
    }

    public func asSharedSequence() -> SharedSequence<SharingStrategy, Bool> {
        loading
    }
}

private final class ActivityToken<E>: ObservableConvertibleType, Disposable {
    private let source: Observable<E>
    private let disposeAction: () -> Void
    private var disposed = false

    init(source: Observable<E>, disposeAction: @escaping () -> Void) {
        self.source = source
        self.disposeAction = disposeAction
    }

    func asObservable() -> Observable<E> { source }

    func dispose() {
        guard !disposed else { return }
        disposed = true
        disposeAction()
    }
}

public extension ObservableConvertibleType {
    func trackActivity(_ activityIndicator: ActivityIndicator) -> Observable<Element> {
        activityIndicator.track(self)
    }
}
