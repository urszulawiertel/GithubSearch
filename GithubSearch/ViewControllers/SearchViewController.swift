//
//  SearchViewController.swift
//  GithubSearch
//
//  Created by Ula on 16/02/2026.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

final class SearchViewController: UIViewController {

    let onRepoSelected = PublishRelay<Repo>()

    private let disposeBag = DisposeBag()
    private let viewModel: SearchViewModel

    private let resultsTableView = UITableView(frame: .zero, style: .plain)
    fileprivate let activityIndicatorView = UIActivityIndicatorView(style: .medium)
    fileprivate let emptyStateLabel = UILabel()

    private let searchController = UISearchController(searchResultsController: nil)

    init(viewModel: SearchViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "GitHub Search"
        view.backgroundColor = .systemBackground

        setupSearch()
        setupUI()
        setupLayout()
        setupBindings()
    }

    private func setupSearch() {
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search repositories"
        definesPresentationContext = true
    }

    private func setupUI() {
        resultsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "RepoCell")
        resultsTableView.keyboardDismissMode = .onDrag
        resultsTableView.tableFooterView = UIView()

        let activityBarButtonItem = UIBarButtonItem(customView: activityIndicatorView)
        navigationItem.rightBarButtonItem = activityBarButtonItem

        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.textColor = .secondaryLabel
        emptyStateLabel.isHidden = true

        view.addSubview(resultsTableView)
        view.addSubview(emptyStateLabel)
    }

    private func setupLayout() {
        resultsTableView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        emptyStateLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().inset(24)
            make.trailing.lessThanOrEqualToSuperview().inset(24)
        }
    }

    private func setupBindings() {
        let queryText = searchController.searchBar.rx.text.orEmpty
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .distinctUntilChanged()
            .share(replay: 1)

        let searchTrigger = searchController.searchBar.rx.searchButtonClicked
            .asSignal()

        let selectedRepo = resultsTableView.rx.modelSelected(Repo.self)
            .throttle(.microseconds(500), scheduler: MainScheduler.instance)
            .asSignal(onErrorSignalWith: .empty())

        let input = SearchViewModel.Input(
            username: queryText.asObservable(),
            searchTap: searchTrigger,
            selectedRepo: selectedRepo
        )

        let output = viewModel.transform(input: input)

        // UI state
        output.isLoading
            .drive(rx.isLoading)
            .disposed(by: disposeBag)

        output.emptyMessage
            .drive(rx.emptyMessage)
            .disposed(by: disposeBag)

        output.errorMessage
            .emit(to: rx.errorMessage)
            .disposed(by: disposeBag)

        // Table data
        output.repos
            .drive(resultsTableView.rx.items(
                cellIdentifier: "RepoCell",
                cellType: UITableViewCell.self
            )) { _, repo, cell in
                var contentConfiguration = cell.defaultContentConfiguration()
                contentConfiguration.text = repo.name
                contentConfiguration.secondaryText = repo.language
                cell.contentConfiguration = contentConfiguration
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
            }
            .disposed(by: disposeBag)

        // Navigation -> Details (single source of truth: output)
        output.openRepoDetails
            .emit(to: onRepoSelected)
            .disposed(by: disposeBag)

        // UX: deselect row
        resultsTableView.rx.itemSelected
            .subscribe(onNext: { [weak self] indexPath in
                self?.resultsTableView.deselectRow(at: indexPath, animated: true)
            })
            .disposed(by: disposeBag)
    }

    fileprivate func showErrorAlert(message: String) {
        let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
    }
}

// MARK: - Rx Bindings
private extension Reactive where Base: SearchViewController {

    var isLoading: Binder<Bool> {
        Binder(base) { viewController, isLoading in
            if isLoading {
                viewController.activityIndicatorView.startAnimating()
            } else {
                viewController.activityIndicatorView.stopAnimating()
            }
        }
    }

    var emptyMessage: Binder<String?> {
        Binder(base) { viewController, message in
            viewController.emptyStateLabel.text = message
            viewController.emptyStateLabel.isHidden = (message == nil)
        }
    }

    var errorMessage: Binder<String?> {
        Binder(base) { viewController, message in
            guard let message else { return }
            viewController.showErrorAlert(message: message)
        }
    }
}
