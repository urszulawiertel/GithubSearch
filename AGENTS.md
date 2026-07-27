# AGENTS.md

## Project overview

This is a UIKit iOS application using:

- Swift
- UIKit
- MVVM
- Coordinator pattern
- RxSwift and RxCocoa
- SnapKit
- XCTest

Preserve the existing architecture and conventions.

Do not rewrite the application using SwiftUI, Combine, TCA, async architecture,
or another architectural pattern unless the task explicitly requires it.

## General working rules

- Keep changes minimal, focused, and production-like.
- Do not perform unrelated refactors.
- Do not rename or move unrelated files.
- Do not change public behavior outside the requested task.
- Inspect the existing implementation before making changes.
- Reuse existing components and patterns where appropriate.
- Do not introduce new dependencies unless explicitly requested.
- Do not modify project structure unless required by the task.
- Do not modify build settings, deployment targets, schemes, or configurations
  unless explicitly required.
- Do not add generated or user-specific Xcode files to source control.

## File organization

Keep types in their appropriate project folders:

- View controllers belong in `ViewControllers`.
- View models belong in `ViewModels`.
- Reusable and screen-specific UIView subclasses belong in `Views`.
- Coordinators belong in `Coordinators`.
- Networking types belong in `Networking`.
- Services belong in `Services`.
- Models belong in `Models`.
- Debug-only functionality belongs in `Debug`.
- Tests belong in the appropriate test target.

Do not declare substantial UIView subclasses at the bottom of a view controller
file when they can be placed in a focused file under `Views`.

Small private helper types may remain in the consuming file only when they are
truly local, trivial, and do not contain meaningful layout or behavior.

When adding a new Swift file:

- Place it in the correct folder.
- Ensure it belongs to the correct Xcode target.
- Ensure it is referenced correctly by the Xcode project.
- Do not accidentally add it only to the filesystem without project membership.
- Do not create duplicate file references.
- Do not modify unrelated project file entries.

## Xcode-generated files

Never add or modify user-specific Xcode data, including:

- `xcuserdata`
- `UserInterfaceState.xcuserstate`
- personal breakpoint files
- user-specific schemes
- Derived Data
- build artifacts

Do not remove existing `.gitignore` rules protecting these files.

Do not add `.DS_Store` files.

## Architecture

Keep MVVM separation clear:

- Views and view controllers handle presentation and user interaction.
- View models expose state and transform inputs into outputs.
- View models must not directly present UIKit components.
- Views must not contain networking or domain business logic.
- View controllers should not perform networking.
- Coordinators handle navigation.
- Services and networking layers handle API communication.
- Prefer dependency injection over creating hard-coded dependencies internally.

Do not move UI configuration into a view model.

Do not move screen navigation into a view model.

## UIKit responsibilities

A UIView subclass should configure and lay out its own internal subviews.

A view controller may:

- compose the screen from views,
- configure screen-level layout,
- bind view model outputs to UI,
- forward user input to the view model,
- coordinate navigation through the existing coordinator.

Keep methods such as `setupUI()`, `setupBindings()`, and `setupActions()`
focused on those responsibilities.

Do not place Rx subscriptions inside reusable UIView subclasses unless that is
already an intentional project convention.

## RxSwift

Follow the existing RxSwift patterns used by the project.

- Dispose subscriptions using the appropriate `DisposeBag`.
- Avoid nested subscriptions.
- Do not call `subscribe` inside another `subscribe`.
- Prefer transformations such as `map`, `flatMapLatest`, `compactMap`,
  `distinctUntilChanged`, and `debounce` where appropriate.
- Use `Driver` or `Signal` for UI-facing streams when consistent with the
  existing implementation.
- Ensure UI-bound streams are safe for the main thread.
- Avoid retain cycles.
- Use `[weak self]` when a subscription stored by `self` captures `self`.
- Do not add `[weak self]` mechanically where no retain cycle can exist.
- Preserve request cancellation behavior where `flatMapLatest` is used.
- Do not trigger duplicate API requests from both the view controller and
  view model.

When changing search behavior, verify:

- typing,
- debounce,
- clearing input,
- whitespace-only input,
- loading state,
- successful results,
- empty results,
- user-not-found state,
- network failure,
- retry or subsequent searches,
- stale request responses.

## UI state management

Treat search states as explicit and mutually consistent.

Typical states include:

- initial or idle,
- loading,
- results,
- empty results,
- user not found,
- recoverable error.

Do not leave stale content visible when transitioning to an empty, loading,
or error state unless preserving content is an explicit product decision.

Expected outcomes such as “user not found” should use a non-blocking inline
state rather than a blocking alert.

Unexpected failures such as connectivity errors or rate limits should follow
the existing error presentation strategy.

When a state changes, verify that unrelated UI elements are reset correctly,
including:

- repository data,
- placeholder visibility,
- loader visibility,
- error presentation,
- pagination state,
- selection state.

## Code style

Write clean, readable, SwiftLint-friendly Swift.

- Follow Swift API Design Guidelines.
- Prefer small, focused types and methods.
- Use clear and intention-revealing names.
- Use explicit access control where reasonable.
- Prefer `final` for classes that are not intended to be subclassed.
- Avoid force unwraps.
- Avoid force casts.
- Avoid implicitly unwrapped optionals unless required by UIKit lifecycle.
- Avoid deeply nested logic.
- Prefer early returns where they improve readability.
- Avoid duplicated code.
- Keep line lengths reasonable.
- Use trailing closure syntax appropriately.
- Use `MARK` sections when they improve navigation.
- Keep formatting consistent with the existing codebase.
- Do not add formatting-only changes to unrelated files.
- Do not introduce clever abstractions for simple behavior.
- Optimize for maintainability and interview readability.

If SwiftLint is already configured, follow its existing rules.

If SwiftLint is not configured:

- write SwiftLint-friendly code,
- do not add SwiftLint as a dependency,
- do not add a new `.swiftlint.yml`,
- do not reformat the entire repository.

## Localization

Do not hard-code new user-facing strings when the project already uses
localization.

When adding or changing visible text:

- update the appropriate `Localizable.strings` files,
- preserve existing localization keys when reasonable,
- avoid duplicate keys,
- verify format placeholders,
- keep accessibility text localized where appropriate.

## Accessibility

For new or changed UI:

- preserve Dynamic Type support,
- use semantic text styles where possible,
- provide meaningful accessibility labels where needed,
- add stable accessibility identifiers when useful for UI tests,
- do not expose decorative images as separate accessibility elements,
- avoid changing existing identifiers without a reason.

## Testing

When behavior changes, update or add focused tests where reasonable.

Tests should cover observable behavior rather than private implementation
details.

For view model changes, verify relevant state transitions.

For view controller or view changes, add UI-level tests only when the project
already has suitable infrastructure or the task explicitly requests them.

Do not:

- delete tests to make the suite pass,
- weaken assertions without justification,
- add meaningless tests,
- rewrite unrelated tests,
- rely on real network calls in unit tests.

Use existing mocks and test conventions where possible.

## Validation before finishing

Before considering the task complete:

1. Review the final diff.
2. Remove unrelated changes.
3. Check for accidental project file modifications.
4. Check that every new file has the correct target membership.
5. Check that no `xcuserdata`, build output, or generated files were added.
6. Build the relevant app target.
7. Run relevant tests where available.
8. Check for compiler warnings introduced by the change.
9. Verify the requested UI behavior manually when practical.

Do not claim that a build or test passed unless it was actually run.

If validation could not be performed, state exactly what was not run and why.

## Final response

After finishing, provide:

1. A concise explanation of the root cause.
2. A summary of the implemented solution.
3. A list of modified and newly created files.
4. The exact tests added or changed.
5. The build and test commands run, with their results.
6. Any remaining follow-up work.

Do not provide a vague summary such as “updated the code.”
Do not claim there is no follow-up work without reviewing the final diff.
