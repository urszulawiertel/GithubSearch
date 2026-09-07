# GitHub Search insights Worker

Production: https://githubsearch-insights.moonshoka.workers.dev

This directory deploys to the existing `githubsearch-insights` Worker. The native app sends repository context over HTTPS; the Worker validates it, calls Workers AI through the `AI` binding, validates the result, and returns the four fields decoded by `RepositoryInsightsProxyService`. No client or server API key is needed. Wrangler OAuth credentials stay in Wrangler's local user configuration, outside this repository and the application.

## Contract

`GET /health` returns `200 {"status":"ok"}` without using AI. It checks HTTP availability, not model availability.

`POST /api/repository-insights` requires `Content-Type: application/json`. The existing Swift encoder sends:

```json
{
  "schemaVersion": 1,
  "locale": "en",
  "repositoryContentIsUntrusted": true,
  "instructions": ["Use only supplied repository facts."],
  "context": {
    "repositoryName": "GithubSearch",
    "fullName": "owner/GithubSearch",
    "description": "A UIKit repository search application using MVVM and RxSwift.",
    "primaryLanguage": "Swift",
    "topics": ["ios", "rxswift"],
    "starCount": 42,
    "licenseName": "MIT License",
    "readmeExcerpt": "Search GitHub repositories and explore repository details.",
    "latestRelease": {
      "name": "Version 1.0",
      "tagName": "v1.0",
      "publishedAt": "2026-04-05T10:00:00Z",
      "notesExcerpt": "Initial release."
    }
  }
}
```

Required envelope fields: all five shown above. Required context fields: `repositoryName`, `fullName`, `topics` (array, possibly empty), and `starCount` (nonnegative safe integer). Other context fields may be absent or null. A supplied release requires nonblank `name` and `tagName`; its date and notes are optional. Dates use ISO 8601. At least one description, language, topic, README, or release is required. Optional strings, when present, must be nonblank. Unknown fields are discarded before inference. Client `instructions` are validated for compatibility but **never used as model instructions**.

Success is `200 application/json`, with no provider wrapper:

```json
{
  "overview": "A repository browser implemented with UIKit and RxSwift.",
  "usefulFor": ["Developers exploring an iOS MVVM example."],
  "nextSteps": ["Consider running the app.", "Consider reviewing search bindings.", "Consider examining the details flow."],
  "questionsToExplore": ["How are stale searches cancelled?"]
}
```

`RESPONSE_SCHEMA` in `src/index.ts` is the schema passed via `response_format: {type: "json_schema", json_schema: ...}`. All four fields are required; additional properties are forbidden. The Worker unwraps Workers AI's `response` internally (object or JSON text), validates it again, and returns only those four fields. The Swift decoder trims strings and requires exactly three next steps.

Errors always use `{"error":{"code":"...","message":"..."}}`. Codes/statuses: `invalid_context`/400, `invalid_json`/400, `not_found`/404, `method_not_allowed`/405 (with Allow), `request_timeout`/408, `body_too_large`/413, `unsupported_media_type`/415, `insufficient_context`/422, `rate_limited`/429 (Retry-After: 60), `invalid_ai_response` or `ai_unavailable`/502, `unavailable`/503, `ai_timeout`/504. The current iOS service maps all non-2xx responses to its inline retryable server failure. No raw model/provider error reaches the client. Cloudflare platform-level rejection before the handler runs can use Cloudflare's own response format.

## Limits and trust boundary

| Input/output | Limit |
| --- | --- |
| Request body, including streamed bodies | 24 KiB UTF-8; 5 seconds to read |
| Repository name / full name | 100 / 256 UTF-16 code units |
| Description / README excerpt | 2,000 / 6,000 code units |
| Language / license | 100 / 256 code units |
| Topics | 20 items, 100 code units each |
| Release name / tag / notes / date | 256 / 128 / 2,000 / 35 code units |
| Locale | 35 code units; language-tag characters only |
| Client instructions (discarded) | 8 items, 500 code units each |
| Generated overview | 1,200 code units |
| Generated arrays | 1–4 usefulFor, exactly 3 nextSteps, 1–4 questions |
| Generated array item | 400 code units, nonblank |
| Serialized model response | 8 KiB |
| Generation | 700 output tokens, temperature 0.2, 25-second response deadline |

The model is `@cf/meta/llama-3.1-8b-instruct-fast`; there are no automatic inference retries. A response deadline bounds the HTTP wait but does not guarantee cancellation of inference already running at Cloudflare. The client can cancel its URLSession request when leaving the screen.

Only the server-owned system message defines instructions. Repository fields are serialized into a separate user message as untrusted data; embedded instructions and role delimiters must be ignored. Locale comes from the existing client contract. The prompt restricts output to supplied facts, asks for concise actions, and explicitly labels suggestions. Prompting is defense in depth, not a guarantee against hallucination or injection. The model has no tools, secrets, external fetches, database, or write capability.

The Rate Limiting binding permits **5 attempts per 60 seconds per Cloudflare-provided connecting IP per location**, before reading a JSON body. Namespace `2609071731` is reserved for this Worker; avoid reusing it for other Workers. Invalid JSON/context attempts also consume allowance. The limiter fails closed if unavailable. Health and rejected routes/methods do not invoke it. No permissive CORS is added.

This is a public portfolio endpoint, not authenticated access. Shared mobile/NAT IPs share allowance; distributed IPs can bypass per-IP limits. Cloudflare counters are local and eventually consistent, not a global budget or exact accounting system. A spoofable client ID would not improve authentication. No App Attest is implemented. Logs contain only a random request ID, status, stable error code and elapsed milliseconds—never IPs, repository content, generated text or provider exceptions.

Workers AI's Free allowance is currently 10,000 neurons/day, resetting at 00:00 UTC; operations fail after exhaustion. Workers Free also has request/CPU limits. No paid plan is enabled by this project. If the account is upgraded separately, usage above the free allocation can incur charges; rate limiting is not a spending cap. Monitor account usage in Cloudflare.

Official references: [JSON mode](https://developers.cloudflare.com/workers-ai/features/json-mode/), [model](https://developers.cloudflare.com/workers-ai/models/llama-3.1-8b-instruct-fast/), [rate-limiter semantics](https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/), [AI free allowance](https://developers.cloudflare.com/workers-ai/platform/pricing/).

## Development, tests and deployment

Use Node.js 22 or newer and npm. From this directory:

```sh
npm ci
npm test
npm run typecheck
npx wrangler deploy --dry-run
npx wrangler login
npm run deploy
```

The checked-in lockfile pins the tools. `wrangler.jsonc` targets the existing Worker and preserves `ai.binding = AI`; compatibility date is `2026-09-01`. Do not deploy using a different Worker name or temporary account. No database, domain or secret provisioning is required. The test suite supplies mocked bindings and never calls real AI. `wrangler dev` can use real remote AI; use unit tests for cost-free validation.

After deployment, check health and one malformed body without invoking AI:

```sh
curl -i https://githubsearch-insights.moonshoka.workers.dev/health
curl -i https://githubsearch-insights.moonshoka.workers.dev/api/repository-insights \
  -H 'Content-Type: application/json' --data '{'
```

For a real inference, save the request above as `/tmp/insights-request.json` and run once:

```sh
curl --max-time 35 -i https://githubsearch-insights.moonshoka.workers.dev/api/repository-insights \
  -H 'Content-Type: application/json' --data-binary @/tmp/insights-request.json
```

## iOS modes and end-to-end check

- **Debug/mock:** select the `DEBUG` scheme; leave `REPOSITORY_INSIGHTS_MODE` unset (or `mock`). Insights are deterministic and local.
- **Debug/proxy:** in the `DEBUG` scheme's Run → Arguments → Environment Variables, enable `REPOSITORY_INSIGHTS_MODE=proxy`. The launch factory injects the production proxy service. No scheme edit needs to be committed.
- **Release:** the `GithubSearch` scheme runs Release and always injects the production proxy, regardless of that environment variable. The URL is public `Info.plist` configuration.

From the repository root, using an available simulator (the verification device was iPhone 17 Pro):

```sh
xcodebuild -workspace GithubSearch.xcworkspace -scheme GithubSearch -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/GithubSearch-insights-build build
xcodebuild -workspace GithubSearch.xcworkspace -scheme GithubSearch -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/GithubSearch-insights-build test
xcodebuild -workspace GithubSearch.xcworkspace -scheme GithubSearch -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/GithubSearch-insights-release build
```

The complete test plan includes unit and UI tests. To focus on insights, append `-only-testing:GithubSearchTests/RepositoryInsightsServiceTests -only-testing:GithubSearchTests/RepoDetailsInsightsViewModelTests` to the test command.

Manual check:

1. Run Debug/proxy with `UI_TEST_SCENARIO` unset. Search `ReactiveX`, open `RxSwift`, wait for README/release sections, and generate insights. Confirm the overview relates to Swift/reactive programming and the four sections appear.
2. Tap Regenerate once; confirm loading then a valid result. Model wording may vary.
3. After details load, disable the Mac's network (simulator) or device connectivity. Generate again and confirm the inline Retry state. Restore connectivity and tap Retry; confirm recovery. This requires a further real inference.
4. Start regeneration and immediately navigate back. Open a different repository. Confirm it starts idle and cannot display the previous repository's result. The existing cancellation unit test independently verifies disposal and rejection of late callbacks.
5. Switch back to Debug/mock for ordinary development. Keep model invocations small; respect 429 and Retry-After.

## Verification record — 2026-09-07

Deployed with Wrangler 4.129.1 to the existing production host; final version ID `d2d389e0-8c9b-488e-947d-2a9436cdd28e`. Both `AI` and `INSIGHTS_RATE_LIMITER` were confirmed in deploy output. Preview URLs remain disabled. Sanitized application logs are enabled; automatic invocation logs are disabled.

- `npm ci`: passed with the portable npm lockfile; audit reported zero vulnerabilities. npm noted optional package lifecycle-script policies; typecheck, tests and Wrangler bundling all succeeded.
- `npm test`: 48 deterministic tests passed, including malformed and oversized requests, schema validation, injection isolation, exact output mapping, provider errors, request/AI deadlines and rate limiting.
- `npm run typecheck`: passed.
- `npx wrangler deploy --dry-run`: passed and listed both bindings.
- `npm run deploy`: passed; the existing Worker was updated, no second Worker created.
- `GET /health`: HTTP 200, `{"status":"ok"}`.
- One real AI POST: HTTP 200 in 2.159 seconds. The request was produced by the unchanged Swift `RepositoryInsightsRequestBuilder`. The response was decoded and validated using the unchanged `RepositoryInsightsResponseDTO.makeDomainModel()` (the original contract source was extracted into a temporary Swift verification script, without introducing another DTO into the project). All four top-level keys matched, with exactly three next steps and no provider wrapper. Overview: “This repository is a UIKit iOS application for searching GitHub repositories, built with Swift and various frameworks.” This confirms functional inference and mapping, not a general model-quality guarantee.
- Malformed production JSON: HTTP 400, `{"error":{"code":"invalid_json","message":"A valid JSON body is required."}}`.
- Debug build: passed.
- Full Debug iOS test plan: **82 unit tests and 7 UI tests passed**, zero failures. Existing insight Retry, duplicate-tap and late-response cancellation tests passed unchanged.
- Release simulator build: passed. A device archive/signing run was not performed.

Exact iOS commands used (from repository root):

```sh
xcodebuild -workspace GithubSearch.xcworkspace -scheme GithubSearch -configuration Debug -destination 'platform=iOS Simulator,id=7233B4C2-AF60-4932-8625-78048521B231' -derivedDataPath /tmp/GithubSearch-insights-build build
xcodebuild -workspace GithubSearch.xcworkspace -scheme GithubSearch -configuration Debug -destination 'platform=iOS Simulator,id=7233B4C2-AF60-4932-8625-78048521B231' -derivedDataPath /tmp/GithubSearch-insights-build test
xcodebuild -workspace GithubSearch.xcworkspace -scheme GithubSearch -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/GithubSearch-insights-release build
```

Added Swift tests in the existing target member `RepositoryInsightsServiceTests.swift`:

- `test_launchConfigurationSelectsExpectedInsightsService`
- `test_requestPreservesSchemaLocaleAndReleaseCodingKeys`
- `test_controlledBackendErrorsMapToRetryableServerError`

Builds emitted existing lint issues in unrelated files, RxSwift/RxCocoa dependency warnings, a missing Metal toolchain search-path warning, the existing SwiftLint script-output warning, and an AppIntents metadata notice. No warnings identified in the changed Swift files. The real-proxy manual UI walkthrough above remains to be performed; automated UI tests used deterministic fixtures. No real inference was added to unit tests. No Xcode project, scheme, user data or generated build output was changed or added to Git; no commit was created.
