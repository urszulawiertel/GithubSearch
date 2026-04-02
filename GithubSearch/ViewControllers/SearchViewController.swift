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

    private enum Constants {
        static let estimatedRowHeight: CGFloat = 104
    }

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
        resultsTableView.register(RepositoryCell.self, forCellReuseIdentifier: RepositoryCell.reuseID)
        resultsTableView.rowHeight = UITableView.automaticDimension
        resultsTableView.estimatedRowHeight = Constants.estimatedRowHeight
        resultsTableView.separatorStyle = .singleLine
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

        output.viewState
            .observe(on: MainScheduler.instance)
            .bind(to: rx.viewState)
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
                cellIdentifier: RepositoryCell.reuseID,
                cellType: RepositoryCell.self
            )) { _, repo, cell in
                cell.configure(with: repo)
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
        if let alertController = presentedViewController as? UIAlertController {
            alertController.message = message
            return
        }

        let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
    }
}

// MARK: - Rx Bindings
private extension Reactive where Base: SearchViewController {

    var viewState: Binder<SearchViewModel.ViewState> {
        Binder(base) { viewController, state in
            viewController.view.bringSubviewToFront(viewController.activityIndicatorView)

            switch state {
            case .loading:
                viewController.emptyStateLabel.isHidden = true
                viewController.resultsTableView.isHidden = true
                viewController.activityIndicatorView.startAnimating()

            case let .prompt(message), let .empty(message):
                viewController.activityIndicatorView.stopAnimating()
                viewController.emptyStateLabel.text = message
                viewController.emptyStateLabel.isHidden = false
                viewController.resultsTableView.isHidden = false

            case .results, .failure:
                viewController.activityIndicatorView.stopAnimating()
                viewController.emptyStateLabel.text = nil
                viewController.emptyStateLabel.isHidden = true
                viewController.resultsTableView.isHidden = false
            }
        }
    }
}
