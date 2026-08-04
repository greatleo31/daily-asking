## Purpose

Defines privacy and security requirements that keep Daily Asking local-first, transparent about outbound AI data, and safe for BYOK usage.

## ADDED Requirements

### Requirement: The app is usable without network access
The system SHALL keep core journal management usable without network access, AI provider configuration, or a backend account.

#### Scenario: First use without AI
- **WHEN** a user opens the app without configuring AI
- **THEN** the user can acknowledge privacy boundaries and manage local records

#### Scenario: Network unavailable
- **WHEN** network access is unavailable
- **THEN** local records remain readable and editable, while real AI generation is unavailable

### Requirement: Secrets are isolated from records and logs
The system SHALL store API keys separately from journal records, artifacts, exports, logs, and migration packages.

#### Scenario: Log sanitization
- **WHEN** the app records diagnostic information
- **THEN** API keys, tokens, secrets, prompts, and oversized user content are omitted or redacted

#### Scenario: Export after BYOK setup
- **WHEN** a user exports data after saving an API key
- **THEN** the export contains no API key, token, secure-storage secret value, or secret alias intended for credential retrieval

### Requirement: Outbound disclosure is mandatory for real AI calls
The system SHALL disclose what will leave the device before every real AI call.

#### Scenario: Disclosure before generation
- **WHEN** a user initiates a real AI generation task
- **THEN** the system lists the provider, route, selected fields, and non-upload guarantee before the user confirms

#### Scenario: User cancels disclosure
- **WHEN** a user cancels the outbound disclosure
- **THEN** no AI request is sent and local data remains unchanged

### Requirement: Generated content must not fabricate career evidence
The system SHALL treat unsupported claims, invented numbers, invented company names, invented project names, and invented responsibilities as invalid output risks.

#### Scenario: Output contains unsupported metric
- **WHEN** generated content includes a metric not present in the selected source records
- **THEN** the system surfaces a risk or validation failure instead of presenting it as verified evidence

#### Scenario: Output asks for missing facts
- **WHEN** evidence is incomplete
- **THEN** the system encourages follow-up questions or missing-field notes rather than fabricating a complete achievement

### Requirement: Privacy boundaries are visible at onboarding and release
The system SHALL explain local-first storage, BYOK behavior, minimal outbound context, and known limits in onboarding and release documentation.

#### Scenario: Onboarding privacy boundary
- **WHEN** a user first opens the app
- **THEN** the app explains that records are local-first and AI calls send only selected task context after user confirmation

#### Scenario: Release documentation
- **WHEN** a user reads the GitHub release or README
- **THEN** the documentation states what data is local, what can be sent to an AI provider, and what is out of scope
