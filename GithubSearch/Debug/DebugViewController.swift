//
//  DebugViewController.swift
//  GithubSearch
//
//  Created by Ula on 03/07/2026.
//

#if DEBUG
import UIKit

/// DEBUG-only debug menu. This view controller is compiled out completely from
/// Release builds by the surrounding compiler condition.
final class DebugViewController: UITableViewController {

    private enum Section: Int, CaseIterable {
        case actions
    }

    private enum Action: CaseIterable {
        case clearImageCache
        case forceEmptyState
        case forceNetworkError
        case showAppInformation
        case resetUserDefaults

        var title: String {
            switch self {
            case .clearImageCache:
                return "Clear Image Cache"
            case .forceEmptyState:
                return "Force Empty State"
            case .forceNetworkError:
                return "Force Network Error"
            case .showAppInformation:
                return "Show App Information"
            case .resetUserDefaults:
                return "Reset UserDefaults"
            }
        }
    }

    private let debugSettings: DebugFlagProviding
    private let imageLoader: ImageLoader
    private let userDefaults: UserDefaults
    private let bundle: Bundle
    private let device: UIDevice

    init(
        debugSettings: DebugFlagProviding = DebugSettings.shared,
        imageLoader: ImageLoader = .shared,
        userDefaults: UserDefaults = .standard,
        bundle: Bundle = .main,
        device: UIDevice = .current
    ) {
        self.debugSettings = debugSettings
        self.imageLoader = imageLoader
        self.userDefaults = userDefaults
        self.bundle = bundle
        self.device = device
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Debug"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: UITableViewCell.reuseIdentifier)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Action.allCases.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: UITableViewCell.reuseIdentifier,
            for: indexPath
        )
        let action = Action.allCases[indexPath.row]

        var configuration = cell.defaultContentConfiguration()
        configuration.text = action.title
        cell.contentConfiguration = configuration
        cell.accessoryType = accessoryType(for: action)

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch Action.allCases[indexPath.row] {
        case .clearImageCache:
            clearImageCache()
        case .forceEmptyState:
            setSearchResponseMode(.empty, confirmationMessage: "Search results will now return the empty state.")
        case .forceNetworkError:
            setSearchResponseMode(.networkError, confirmationMessage: "Search requests will now return a network error.")
        case .showAppInformation:
            showAppInformation()
        case .resetUserDefaults:
            confirmResetUserDefaults()
        }
    }

    private func clearImageCache() {
        imageLoader.clearCache()
        showConfirmation(message: "Image cache cleared.")
    }

    private func setSearchResponseMode(_ mode: DebugSearchResponseMode, confirmationMessage: String) {
        debugSettings.searchResponseMode = mode
        tableView.reloadData()
        showConfirmation(message: confirmationMessage)
    }

    private func showAppInformation() {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        let message = [
            "Version: \(version)",
            "Build: \(build)",
            "iOS: \(device.systemVersion)",
            "Device: \(device.name)"
        ].joined(separator: "\n")

        let alertController = UIAlertController(
            title: "App Information",
            message: message,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: L10n.Common.okButton, style: .default))
        present(alertController, animated: true)
    }

    private func confirmResetUserDefaults() {
        let alertController = UIAlertController(
            title: "Reset UserDefaults",
            message: "This removes all UserDefaults values owned by the app.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alertController.addAction(UIAlertAction(title: "Reset", style: .destructive) { [weak self] _ in
            self?.resetUserDefaults()
        })
        present(alertController, animated: true)
    }

    private func resetUserDefaults() {
        if let bundleIdentifier = bundle.bundleIdentifier {
            userDefaults.removePersistentDomain(forName: bundleIdentifier)
        }
        userDefaults.synchronize()
        tableView.reloadData()
        showConfirmation(message: "UserDefaults reset.")
    }

    private func accessoryType(for action: Action) -> UITableViewCell.AccessoryType {
        switch action {
        case .forceEmptyState where debugSettings.searchResponseMode == .empty,
             .forceNetworkError where debugSettings.searchResponseMode == .networkError:
            return .checkmark
        default:
            return .none
        }
    }

    private func showConfirmation(message: String) {
        let alertController = UIAlertController(
            title: "Debug",
            message: message,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: L10n.Common.okButton, style: .default))
        present(alertController, animated: true)
    }
}

private extension UITableViewCell {
    static let reuseIdentifier = "DebugCell"
}
#endif
