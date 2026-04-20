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
        static let searchTextFieldAccessibilityIdentifier = "search.usernameField"
        static let resultsTableAccessibilityIdentifier = "search.resultsTable"
        static let emptyStateAccessibilityIdentifier = "search.emptyStateLabel"
    }

    let onRepoSelected = PublishRelay<Repo>()

    private let disposeBag = DisposeBag()
    private let viewModel: SearchViewModel

    fileprivate let resultsTableView = UITableView(frame: .zero, style: .plain)
    fileprivate let activityIndicatorView = UIActivityIndicatorView(style: .medium)
    fileprivate let emptyStateLabel = UILabel()

    private let searchController = UISearchController(searchResultsController: nil)
    private let sortChangedRelay = PublishRelay<SearchSort>()
    private lazy var sortBarButtonItem = UIBarButtonItem(
        title: L10n.Search.sortButtonTitle,
        image: nil,
        primaryAction: nil,
        menu: makeSortMenu(selectedSort: .bestMatch)
    )

    init(viewModel: SearchViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.Search.navigationTitle
        view.backgroundColor = .systemBackground

        setupSearch()
        setupNavigationBar()
        setupUI()
        setupLayout()
        setupBindings()
    }

    private func setupSearch() {
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.placeholder = L10n.Search.usernamePlaceholder
        searchController.searchBar.searchTextField.accessibilityIdentifier = Constants.searchTextFieldAccessibilityIdentifier
        definesPresentationContext = true
    }

    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = sortBarButtonItem
    }

    private func setupUI() {
        resultsTableView.register(RepositoryCell.self, forCellReuseIdentifier: RepositoryCell.reuseID)
        resultsTableView.rowHeight = UITableView.automaticDimension
        resultsTableView.estimatedRowHeight = Constants.estimatedRowHeight
        resultsTableView.separatorStyle = .singleLine
        resultsTableView.keyboardDismissMode = .onDrag
        resultsTableView.tableFooterView = UIView()
        resultsTableView.accessibilityIdentifier = Constants.resultsTableAccessibilityIdentifier

        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.textColor = .secondaryLabel
        emptyStateLabel.isHidden = true
        emptyStateLabel.accessibilityIdentifier = Constants.emptyStateAccessibilityIdentifier

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
        let loadNextPageRelay = PublishRelay<Void>()
        let queryText = searchController.searchBar.rx.text.orEmpty
            .asObservable()

        let input = SearchViewModel.Input(
            username: queryText,
            sortChanged: sortChangedRelay.asObservable(),
            loadNextPage: loadNextPageRelay.asObservable()
        )

        let output = viewModel.transform(input: input)

        output.state
            .drive(rx.searchState)
            .disposed(by: disposeBag)

        output.alertMessage
            .emit(onNext: { [weak self] message in
                self?.showErrorAlert(message: message)
            })
            .disposed(by: disposeBag)

        output.state
            .map(\.repos)
            .distinctUntilChanged()
            .drive(resultsTableView.rx.items(
                cellIdentifier: RepositoryCell.reuseID,
                cellType: RepositoryCell.self
            )) { _, repo, cell in
                cell.configure(with: repo)
            }
            .disposed(by: disposeBag)

        resultsTableView.rx.modelSelected(Repo.self)
            .bind(to: onRepoSelected)
            .disposed(by: disposeBag)

        resultsTableView.rx.itemSelected
            .subscribe(onNext: { [weak self] indexPath in
                self?.resultsTableView.deselectRow(at: indexPath, animated: true)
            })
            .disposed(by: disposeBag)

        resultsTableView.rx.didScroll
            .withLatestFrom(output.state.asObservable()) { [weak self] _, state -> Void? in
                guard let self else {
                    return nil
                }

                let thresholdOffset = max(
                    self.resultsTableView.contentSize.height - (self.resultsTableView.bounds.height * 1.5),
                    0
                )

                guard self.resultsTableView.contentOffset.y >= thresholdOffset,
                      !state.repos.isEmpty,
                      state.hasMorePages,
                      !state.isLoadingNextPage else {
                    return nil
                }
                return ()
            }
            .compactMap { $0 }
            .bind(to: loadNextPageRelay)
            .disposed(by: disposeBag)
    }

    fileprivate func showErrorAlert(message: String) {
        if let alertController = presentedViewController as? UIAlertController {
            alertController.message = message
            return
        }

        let alertController = UIAlertController(
            title: L10n.Common.errorTitle,
            message: message,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: L10n.Common.okButton, style: .default))
        present(alertController, animated: true)
    }

    fileprivate func updateSortMenu(selectedSort: SearchSort) {
        sortBarButtonItem.menu = makeSortMenu(selectedSort: selectedSort)
    }

    private func makeSortMenu(selectedSort: SearchSort) -> UIMenu {
        UIMenu(
            title: "",
            children: SearchSort.allCases.map { sort in
                UIAction(
                    title: sort.title,
                    state: sort == selectedSort ? .on : .off
                ) { [weak self] _ in
                    self?.sortChangedRelay.accept(sort)
                }
            }
        )
    }
}

// MARK: - Rx Bindings
private extension Reactive where Base: SearchViewController {

    var searchState: Binder<SearchViewModel.SearchState> {
        Binder(base) { viewController, state in
            viewController.view.bringSubviewToFront(viewController.activityIndicatorView)
            viewController.updateSortMenu(selectedSort: state.selectedSort)

            switch state.phase {
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
