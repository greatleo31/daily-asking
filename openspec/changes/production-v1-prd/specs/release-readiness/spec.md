## Purpose

Defines the GitHub Release standard for Daily Asking v0.1 so the app is installable, documented, and backed by repeatable verification evidence.

## ADDED Requirements

### Requirement: Release build is reproducible through documented commands
The system SHALL document and support repeatable commands for dependency install, analysis, tests, and Android release APK build.

#### Scenario: Developer follows README
- **WHEN** a developer follows the documented local verification commands in a Flutter-ready environment
- **THEN** the commands complete or report actionable environment prerequisites

#### Scenario: Missing Flutter environment
- **WHEN** Flutter or Dart CLI is unavailable
- **THEN** release documentation identifies Flutter SDK installation as a prerequisite rather than treating the app as verified

### Requirement: CI verifies release-critical checks
The repository SHALL run automated checks for analysis, tests, and Android release build before claiming a GitHub Release is production-ready.

#### Scenario: Pull request check
- **WHEN** a pull request targets the production release branch or main branch
- **THEN** CI runs Flutter analysis and tests

#### Scenario: Release build check
- **WHEN** release artifacts are prepared
- **THEN** CI or a documented local run produces a release APK build result attached to the release evidence

### Requirement: GitHub Release includes required artifacts and notes
The system SHALL publish each production GitHub Release with APK, version, release notes, verification summary, privacy notes, and known limitations.

#### Scenario: Release notes complete
- **WHEN** a release is published
- **THEN** the release notes include user-visible changes, verification commands/results, privacy model, known limitations, and upgrade notes

#### Scenario: APK attached
- **WHEN** a release is published for Android users
- **THEN** an Android APK artifact is attached or the release explicitly states why no APK is available

### Requirement: Release signing posture is explicit
The system SHALL state whether the release APK uses debug signing, local release signing, or CI-managed signing, and SHALL NOT commit signing secrets.

#### Scenario: Debug signing retained
- **WHEN** a release candidate still uses debug signing
- **THEN** the release notes and README mark it as a GitHub preview release rather than an app-store-ready build

#### Scenario: Signing secret needed
- **WHEN** release signing uses private credentials
- **THEN** the credentials are provided outside the repository and are not committed to source control

### Requirement: Repository documentation supports open-source review
The repository SHALL include enough documentation for users and reviewers to understand usage, privacy boundaries, setup, verification, and contribution constraints.

#### Scenario: README review
- **WHEN** a reviewer opens the repository
- **THEN** the README explains product purpose, installation, BYOK setup, offline behavior, AI disclosure, verification commands, and known limits

#### Scenario: Security review
- **WHEN** a reviewer checks security posture
- **THEN** the repository documents how secrets are handled and how to report sensitive issues
