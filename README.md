# GitHubSearch

GitHubSearch is an iOS app for searching public GitHub repositories by username. It is built with UIKit using MVVM with Coordinators, RxSwift/RxCocoa for reactive bindings, and the GitHub REST API for data fetching.

The app focuses on a clear search flow: type a username, sort and browse paginated repositories, and open a dedicated insights screen for a selected repository.

## Screenshots

| Demo | Search | Results | Details |
|------|--------|---------|---------|
| <img src="./Screenshots/demo.gif" alt="Demo recording" height="478" /> | <img src="./Screenshots/search.png" alt="Search screen" height="478" /> | <img src="./Screenshots/results.png" alt="Results screen" height="478" /> | <img src="./Screenshots/details.png" alt="Repository details screen" height="478" /> |

## Architecture

The project uses `MVVM + Coordinator` to keep presentation logic, view code, and navigation responsibilities separate.

- `ViewControllers` handle UIKit layout, bindings, and rendering UI state.
- `ViewModels` transform inputs into outputs and own screen state.
- `Coordinators` manage navigation so screen transitions do not leak into view controllers.
- `Services` isolate networking, repository-details caching, and image loading concerns behind small protocols.

RxSwift/RxCocoa is used to model user input and async events as observable streams. In this project it keeps the search flow predictable: text input, debounced requests, pagination triggers, and UI state updates are all expressed as one-way data flow instead of scattered delegate callbacks and mutable UI logic.

## Features

- Search repositories by GitHub username
- Debounced search input
- Repository sorting through a navigation-bar menu
- Pagination with infinite scroll
- Repository details with activity statistics, metadata, and topics
- Language breakdown, README preview, and latest release insights
- Pull-to-refresh for repository insights
- Open repositories in an in-app browser
- Remote image loading with in-memory caching
- Request deduplication for concurrent image loads
- User-friendly error messages
- Localization through `L10n`
- Accessibility identifiers and labels for key UI elements
- DEBUG-only menu for forcing search states, clearing the image cache, viewing app information, and resetting app preferences

## Key Decisions

### Debounce strategy

Search input is trimmed, deduplicated, and debounced for 500 milliseconds before the initial request is made. Empty input is handled immediately to cancel a pending search and reset the screen back to a prompt state without waiting for the debounce interval.

The goal was to reduce unnecessary API calls while keeping the UI responsive. A simple fixed debounce is enough for this use case and keeps the behavior easy to reason about and test.

### Sorting

The Sort button in the navigation bar presents a menu with a checkmark beside the active option:

- `Best Match` is selected by default and uses the API's default repository ordering.
- `Stars` orders repositories by star count in descending order within each fetched page.
- `Updated` requests repositories ordered by their last update.
- `Name` requests repositories ordered by full repository name.

Changing the selection clears the current results and immediately restarts the current search from page one. Subsequent pages keep the selected sort option. If there is no active username, the selection is retained and applied to the next search.

### Pagination approach

Pagination is intentionally simple. The `SearchViewModel` tracks:

- current query
- selected sort
- current page
- accumulated repositories
- whether another page exists
- whether a page request is already in progress

The next page is requested when the list is scrolled near the end. The GitHub `Link` header is used to determine whether another page exists. There is no generic pagination abstraction because the app only has one paginated flow, and a local, screen-specific implementation keeps the code smaller and easier to maintain.

### State handling in `SearchViewModel`

`SearchViewModel` exposes a focused `SearchState` containing the normalized query, selected sort, repositories, pagination state, and a rendering phase:

- `prompt`
- `loading`
- `results`
- `empty`
- `failure`

This keeps view rendering explicit and avoids spreading conditional UI logic across the view controller. User-facing errors are exposed as a separate signal, which allows the screen to preserve already loaded results when a later pagination request fails. Responses for an old username or sort selection are prevented from replacing the active results.

### Repository details loading

The details screen renders the repository data already returned by the search request, then loads language usage, a README preview, and the latest release as independent sections. Each section has its own loading, empty, and failure state so one unavailable endpoint does not hide the rest of the screen.

Language and README responses are cached in memory for the current service instance. Pull-to-refresh bypasses those caches and reloads the details sections.

### Image loading

Image loading is implemented as a dedicated service with two practical optimizations:

- `NSCache` stores previously loaded images in memory
- in-flight request deduplication ensures that concurrent requests for the same URL share one network task

This is enough for an app of this size and avoids bringing in a third-party image pipeline when the required behavior is limited to avatar loading.

## Error Handling

The networking layer maps common failure cases to user-facing messages:

- invalid input
- missing user (`404`)
- connectivity issues
- GitHub rate limiting (`403`)
- unknown or decoding failures

The search screen presents errors in an alert and only switches to a failure state on the initial load. If a later page request fails, the current results remain visible and the user still receives feedback. This keeps the failure behavior less disruptive during pagination.

Repository-insight failures are contained within the affected section. Missing language data, README content, or releases are presented as empty states rather than making the whole details screen fail.

## Testing

The shared `GithubSearch.xctestplan` runs both the unit and UI test targets. Unit coverage includes:

- `SearchViewModel`
- pagination behavior
- sorting and stale-response handling
- `GitHubService`
- `ImageLoader`
- `RepoDetailsViewModel`
- `RepositoryCell`

`RxTest` is used for deterministic testing of reactive streams such as debounced input and pagination timing. `RxBlocking` is used where blocking assertions are a better fit, particularly for service-level tests.

The tests focus on behavior that is easy to regress:

- debounce timing, cancellation, and empty-input reset
- appending and resetting paginated results
- preventing duplicate page loads while a request is in flight
- restarting and continuing pagination with the selected sort
- ignoring stale username and sort responses
- mapping API and connectivity errors
- image caching, cancellation, MIME validation, and request deduplication
- loading, caching, refresh, formatting, and fallback behavior for repository insights
- avatar loading and cell-reuse safety

UI tests cover the successful search-to-details flow, the empty search state, launch behavior, and launch performance using deterministic service fixtures.

## Trade-offs

Some decisions were intentionally kept conservative:

- No generic pagination abstraction. There is a single paginated flow, so a screen-specific implementation is easier to follow.
- No offline persistence or search-results cache. The app reads directly from the GitHub API and only keeps image, language, and README data in memory.
- No external image library. The custom image loader covers the required behavior without adding more dependencies.
- No broader data layer abstraction beyond what the current scope needs. Protocol boundaries exist where they support testing and separation of concerns.

These choices keep the project focused on a clean implementation of the core search experience instead of adding architecture that the app does not yet need.

## Tech Stack

- UIKit
- iOS 16+
- MVVM + Coordinator
- RxSwift / RxCocoa 6.9
- GitHub REST API
- SnapKit
- XCTest
- RxTest
- RxBlocking
- CocoaPods

## How to Run

Requirements:

- Xcode capable of building for the iOS 16 deployment target
- CocoaPods

1. Install dependencies:

```bash
pod install
```

Dependencies are not committed to the repository, so this step is required after cloning.

2. Open the workspace:

```bash
open GithubSearch.xcworkspace
```

3. Build and run the `GithubSearch` scheme in Xcode.

To run the unit and UI test suites together, use Product > Test with the shared `GithubSearch` scheme and its `GithubSearch.xctestplan`.

For manual state testing, run the `DEBUG` scheme and open the Debug button on the search screen. The debug menu is compiled out of Release builds.

## Support

If you have any issues, contact: urszulawiertel@gmail.com
