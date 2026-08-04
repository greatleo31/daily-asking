## Context

See `proposal.md` for motivation and product scope. The current codebase is a Flutter Android app with Riverpod state controllers, GoRouter routes, local journal persistence through `shared_preferences`, BYOK settings through `flutter_secure_storage`, prompt templates in assets, a Fake LLM client, and an OpenAI-compatible client that is not yet connected to the generation UI.

This change is single-machine full stack: the APK is the product surface, local storage is the data layer, OpenAI-compatible providers are external API dependencies, and GitHub Release is the operations surface. The existing Cloudflare Worker gateway remains out of the v0.1 production path.

## Goals / Non-Goals

**Goals:**

- Keep the app usable offline for journal CRUD, search, filtering, and export.
- Route real AI generation through explicit BYOK provider configuration and pre-send disclosure.
- Preserve fact boundaries by validating prompt outputs before treating them as artifacts.
- Make release readiness repeatable through CI, APK build evidence, README, privacy documentation, and release notes.
- Keep implementation small enough for incremental OpenSpec apply tasks.

**Non-Goals:**

- No cloud account, sync backend, hosted model proxy, admin portal, payment, or app-store release.
- No production Worker gateway integration in v0.1.
- No encrypted full journal database unless a later spec changes the storage privacy requirement.

## Decisions

### 1. Use local repository boundaries for journal and artifact data

Journal entries and generated artifacts should be accessed through repository interfaces instead of directly from UI pages. The existing `Entry` and `Artifact` domain objects remain the behavior vocabulary, but persistence details can change from `shared_preferences` to a more durable local store without changing specs.

Alternatives considered:

- Keep all local data in `shared_preferences`: fastest, but weak for search/filter/export growth and corrupt-data recovery.
- Introduce a local database immediately: better long-term data model, but adds migration and dependency weight. Use only if implementation confirms `shared_preferences` cannot meet v0.1 search/export safely.

### 2. Keep BYOK direct as the only v0.1 real AI route

The generation UI should choose Fake client only for tests/demo fallback and OpenAI-compatible client only when the user has saved provider config and confirmed outbound disclosure. The Worker gateway should remain visibly out of scope to avoid accidental server responsibilities.

Alternatives considered:

- Official gateway: gives centralized control, but requires auth, invite validation, rate limiting, secret operations, logs, and deployment readiness.
- Fake-only release: easier, but does not satisfy the product promise of user-configured AI generation.

### 3. Treat prompt output contracts as validation gates

Prompt templates already define output contracts. Generation should parse provider output against the selected artifact contract before saving or displaying it as a successful artifact. Invalid JSON, empty provider content, or missing required fields should be user-actionable errors.

Alternatives considered:

- Display raw model text: fast but unsafe for a product whose value depends on honest, structured evidence.
- Hardcode per-page parsing without prompt metadata: simpler initially, but causes prompt/schema drift.

### 4. Use explicit disclosure state before all real AI sends

Before sending to a real provider, the UI should present provider, model, route, selected fields, source entry count/date range, and the guarantee that unrelated journal entries are not included. Cancel must result in no request.

Alternatives considered:

- Show one-time onboarding only: insufficient because each AI task can send different source data.
- Hidden disclosure in settings: easier but fails the minimal outbound context requirement.

### 5. Define GitHub Release as preview-production, not app-store production

v0.1 release readiness means a downloadable APK, CI evidence, docs, privacy notes, and known limitations. If debug signing remains, release docs must state it is a GitHub preview APK rather than app-store-ready production.

Alternatives considered:

- App-store-level signing and policy package: more complete but outside this scope.
- Portfolio-only repository: too weak for the requested production-grade GitHub release.

## Module Boundaries

- Frontend: onboarding, journal editor/list, artifact generation, settings, export UI, error/empty/loading states.
- Data: entry and artifact repositories, local persistence, import/export package validation, schema/version migration handling.
- API: OpenAI-compatible chat completions only; request context must be assembled from selected source records and prompt template.
- Backend: no production owned backend in v0.1; gateway code may remain but must not be presented as a configured production path.
- Testing: domain/unit tests, repository tests, LLM client/error mapping tests, widget tests for core flows, CI release checks.
- Operations: GitHub Actions, APK build, release notes, README/privacy docs, signing posture and secret scanning.

Dependency direction should remain UI → controller/application → repository/client → platform or external provider. UI must not read secure secrets directly except through the settings/generation application layer.

## Data and Migration Plan

- Keep `Entry` field semantics stable: id, date, task, context, action, result, blocker, tags, createdAt, updatedAt.
- Add artifact persistence only after output validation is defined, with source entry ids, type, content, prompt version, model info, and createdAt.
- Introduce storage versioning for exported packages and any local schema migration.
- For existing users with `daily_asking.entries.v1`, load and preserve current entries before moving to any new local store.
- If migration fails, show recovery/error state and do not overwrite the original stored payload.
- Rollback for v0.1 is source-level: because no remote migration exists, rollback means keeping previous local payload readable or leaving it untouched on failed migration.

## Security, Logging, and Observability

- API Key values must only flow through secure storage and request authorization headers.
- Logs must omit API keys, tokens, prompts, long user content, and provider responses that may contain user data.
- Export and migration packages must exclude provider secret values and secret aliases intended for credential retrieval.
- User-facing errors should include enough action guidance without raw secrets or full provider payloads.
- Observability for v0.1 is local and CI-oriented: test output, build logs, release notes, and safe debug logs. No remote telemetry is required.

## Failure Modes

- Local data cannot parse → show local data load failure, avoid automatic overwrite, offer export/recovery path when available.
- Local save/export fails → keep in-memory state consistent with persisted state and surface retryable error.
- AI not configured → block real generation and route user to settings or demo mode.
- API key invalid/forbidden → show credential/action error and redact credentials.
- Provider rate limit/network timeout → show retry-later state and leave journal/artifacts unchanged.
- Provider returns empty or invalid JSON → show unusable output state and do not save as successful artifact.
- CI/build unavailable due to missing Flutter → document prerequisite and do not claim release verification complete.

## Rollout and Release Plan

1. Land OpenSpec PRD/design/tasks on `feature/production-prd-sdd`.
2. Implement in small feature branches or follow-up commits according to `tasks.md`.
3. Add CI before claiming release readiness.
4. Produce APK build evidence and update README/privacy/release notes.
5. Tag a GitHub preview release only after analyze/test/build evidence exists.

## Open Questions

- None blocking the v0.1 PRD. The final signing strategy can remain a documented release-readiness task as long as release notes accurately label debug-signed preview APKs.
