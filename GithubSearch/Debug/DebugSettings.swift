//
//  DebugSettings.swift
//  GithubSearch
//
//  Created by Ula on 03/07/2026.
//

#if DEBUG
import Foundation

/// DEBUG-only flags used to alter app behavior through injectable services.
/// This file is excluded by the Swift compiler in Release builds.
protocol DebugFlagProviding: AnyObject {
    var searchResponseMode: DebugSearchResponseMode { get set }
}

/// DEBUG-only response modes for the search service decorator.
/// Keeping these flags outside SearchViewModel avoids temporary view-model hacks.
enum DebugSearchResponseMode: String {
    case live
    case empty
    case networkError
}

/// DEBUG-only settings storage. Values live in UserDefaults so future debug
/// tooling can inject the same flags across app launches while Release builds
/// compile this type out completely.
final class DebugSettings: DebugFlagProviding {

    static let shared = DebugSettings()

    private enum Key {
        static let searchResponseMode = "debug.searchResponseMode"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var searchResponseMode: DebugSearchResponseMode {
        get {
            guard let rawValue = userDefaults.string(forKey: Key.searchResponseMode),
                  let mode = DebugSearchResponseMode(rawValue: rawValue) else {
                return .live
            }
            return mode
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Key.searchResponseMode)
        }
    }
}
#endif
