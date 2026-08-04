## 1. Spec and Project Guardrails

- [x] 1.1 Add project-level AI collaboration instructions that require Chinese responses, OpenSpec-first changes, minimal edits, and verification evidence.
- [x] 1.2 Add or update README sections for product purpose, install path, BYOK setup, offline capabilities, privacy boundaries, verification commands, and known limits.
- [x] 1.3 Add security/reporting documentation that states API keys must not be committed, logged, exported, or included in migration packages.

## 2. Data and Journal Management

- [x] 2.1 Add journal repository tests for create, read, update, delete, sorting, timestamp behavior, and corrupt local payload handling.
- [x] 2.2 Implement editable journal entries with stable ids and updated timestamps.
- [x] 2.3 Add journal keyword search and date-range filtering with empty states that do not imply data loss.
- [x] 2.4 Add selected/all-entry export in Markdown and JSON, with tests proving secrets and provider config are excluded.
- [x] 2.5 Add local data failure states for load, save, parse, and export errors.

## 3. AI Generation

- [x] 3.1 Add unit tests for prompt registry loading and required output contract validation for all prompt templates.
- [x] 3.2 Connect configured BYOK provider and secure API key retrieval to the AI generation path.
- [x] 3.3 Add outbound disclosure and confirmation before every real AI request.
- [x] 3.4 Implement follow-up question generation from selected records.
- [x] 3.5 Implement resume bullet, weekly report, and interview card generation from selected records or date ranges.
- [x] 3.6 Add user-facing handling for missing AI config, invalid credentials, provider limit, network failure, empty response, and malformed output.

## 4. Privacy and Security

- [x] 4.1 Add tests proving API keys are stored only through secure storage and are removed when configuration is cleared.
- [x] 4.2 Extend safe logging tests to cover keys, tokens, prompts, oversized user content, and provider responses.
- [x] 4.3 Ensure onboarding and generation disclosure state the local-first model, selected-field outbound scope, and no full-journal default upload.
- [x] 4.4 Add validation or risk surfacing for generated content that includes unsupported metrics or unsupported claims.

## 5. Release Readiness

- [x] 5.1 Add GitHub Actions workflow for Flutter dependency install, analyze, and test.
- [x] 5.2 Add Android release APK build workflow or documented release-build command with artifact capture.
- [x] 5.3 Document APK signing posture, including explicit warning if debug signing is used for GitHub preview releases.
- [x] 5.4 Add release notes template covering user-visible changes, verification evidence, privacy model, known limitations, and upgrade notes.
- [x] 5.5 Run secret scan or equivalent repository search and record that no real API keys are committed.

## 6. Validation

- [x] 6.1 Run `openspec validate production-v1-prd --strict` and fix all artifact issues.
- [x] 6.2 Run `flutter analyze` in a Flutter-ready environment and record the result.
- [x] 6.3 Run `flutter test` in a Flutter-ready environment and record the result.
- [x] 6.4 Run Android release APK build in a Flutter-ready environment and record artifact path and signing posture.
- [x] 6.5 Record product-owner acceptance that developer/manual device verification is skipped for this iteration; rely on OpenSpec validation, analyze, automated tests, secret scan, and APK build evidence for this acceptance pass.
