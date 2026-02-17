//
//  ViewController.swift
//  GithubSearch
//
//  Created by Ula on 16/02/2026.
//

import UIKit
import SnapKit

final class SearchViewController: UIViewController {

    // MARK: - UI

    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search GitHub users"
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.returnKeyType = .search
        return searchBar
    }()

    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.keyboardDismissMode = .onDrag
        tableView.tableFooterView = UIView()
        tableView.register(UserCell.self, forCellReuseIdentifier: UserCell.reuseID)
        return tableView
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.hidesWhenStopped = true
        return activityIndicator
    }()

    private let errorLabel: UILabel = {
        let errorLabel = UILabel()
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        errorLabel.font = .systemFont(ofSize: 14)
        errorLabel.textColor = .secondaryLabel
        errorLabel.isHidden = true
        return errorLabel
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "GitHub Search"
        view.backgroundColor = .systemBackground

        setupUI()
        setupLayout()
        setupTableViewFallbackDataSource()
    }

    // MARK: - Setup

    private func setupUI() {
        view.addSubview(searchBar)
        view.addSubview(tableView)
        view.addSubview(errorLabel)
        view.addSubview(activityIndicator)

        errorLabel.text = nil
        activityIndicator.stopAnimating()
    }

    private func setupLayout() {
        searchBar.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            $0.leading.trailing.equalToSuperview()
        }

        tableView.snp.makeConstraints {
            $0.top.equalTo(searchBar.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        errorLabel.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(24)
        }

        activityIndicator.snp.makeConstraints {
            $0.center.equalToSuperview()
        }
    }

    private func setupTableViewFallbackDataSource() {
        tableView.dataSource = self
        tableView.delegate = self
    }

    // MARK: - UI State helpers

    func setLoading(_ isLoading: Bool) {
        if isLoading {
            errorLabel.isHidden = true
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    func setError(_ message: String?) {
        errorLabel.text = message
        errorLabel.isHidden = (message == nil)
    }
}

// MARK: - UITableViewDataSource (placeholder)

extension SearchViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        8 // placeholder
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: UserCell.reuseID, for: indexPath) as? UserCell else {
            return UITableViewCell()
        }
        cell.configure(login: "placeholder_user_\(indexPath.row)", subtitle: "https://github.com/placeholder")
        return cell
    }
}
