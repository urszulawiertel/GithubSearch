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

    fileprivate let resultsTableView = UITableView(frame: .zero, style: .plain)
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
        title = "User Repositories"
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
        searchController.searchBar.placeholder = "Enter a GitHub username"
        definesPresentationContext = true
    }

    private func setupUI() {
        resultsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "RepoCell")
        resultsTableView.keyboardDismissMode = .onDrag
        resultsTableView.tableFooterView = UIView()

        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.textColor = .secondaryLabel
        emptyStateLabel.isHidden = true

        emptyStateLabel.frame = resultsTableView.bounds
        emptyStateLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        resultsTableView.backgroundView = emptyStateLabel

        view.addSubview(resultsTableView)

        activityIndicatorView.hidesWhenStopped = true
        activityIndicatorView.stopAnimating()
        view.addSubview(activityIndicatorView)

        view.bringSubviewToFront(activityIndicatorView)
    }

    private func setupLayout() {
        resultsTableView.snp.makeConstraints {
            $0.edges.equalTo(view.safeAreaLayoutGuide)
        }

        activityIndicatorView.snp.makeConstraints {
            $0.center.equalToSuperview()
        }
    }

    private func setupBindings() {
        let queryText = searchController.searchBar.rx.text.orEmpty
            .asObservable()

        let selectedRepo = resultsTableView.rx.modelSelected(Repo.self)
            .asObservable()

        let input = SearchViewModel.Input(
            username: queryText,
            selectedRepo: selectedRepo
        )

        let output = viewModel.transform(input: input)

        output.isLoading
            .observe(on: MainScheduler.instance)
            .bind(to: rx.isLoading)
            .disposed(by: disposeBag)

        output.emptyMessage
            .observe(on: MainScheduler.instance)
            .bind(to: rx.emptyMessage)
            .disposed(by: disposeBag)

        output.errorMessage
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] message in
                self?.showErrorAlert(message: message)
            })
            .disposed(by: disposeBag)

        output.repos
            .observe(on: MainScheduler.instance)
            .bind(to: resultsTableView.rx.items(
                cellIdentifier: "RepoCell",
                cellType: UITableViewCell.self
            )) { _, repo, cell in
                var content = cell.defaultContentConfiguration()
                content.text = repo.name
                content.secondaryText = repo.language
                cell.contentConfiguration = content
                cell.accessoryType = .disclosureIndicator
            }
            .disposed(by: disposeBag)

        output.openRepoDetails
            .bind(to: onRepoSelected)
            .disposed(by: disposeBag)

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
        Binder(base) { viewController, loading in
            viewController.view.bringSubviewToFront(viewController.activityIndicatorView)

            if loading {
                viewController.emptyStateLabel.isHidden = true
                viewController.resultsTableView.isHidden = true
                viewController.activityIndicatorView.startAnimating()
            } else {
                viewController.activityIndicatorView.stopAnimating()
                viewController.resultsTableView.isHidden = false
            }
        }
    }

    var emptyMessage: Binder<String?> {
        Binder(base) { viewController, message in
            viewController.emptyStateLabel.text = message
            viewController.emptyStateLabel.isHidden = (message == nil)
        }
    }
}
