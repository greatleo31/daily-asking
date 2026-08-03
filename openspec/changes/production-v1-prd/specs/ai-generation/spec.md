## Purpose

Defines BYOK AI generation for fact-preserving follow-up questions, resume bullets, weekly reports, and interview cards based only on user-selected records.

## ADDED Requirements

### Requirement: AI provider configuration is user controlled
The system SHALL let users configure an OpenAI-compatible provider using provider name, base URL, model, and API key, and SHALL allow clearing that configuration.

#### Scenario: Save provider configuration
- **WHEN** a user saves a provider name, base URL, model, and API key
- **THEN** the system reports the provider as configured without displaying the API key in plain text

#### Scenario: Clear provider configuration
- **WHEN** a user clears AI configuration
- **THEN** future real AI generation is unavailable until a new valid configuration is provided

### Requirement: AI requests require source selection and disclosure
The system SHALL require a user-visible source selection and outbound disclosure before sending any real AI request.

#### Scenario: Confirm outbound AI request
- **WHEN** a user requests AI generation for selected records
- **THEN** the system shows provider, model, call route, selected source fields, and a confirmation action before sending the request

#### Scenario: No selected source
- **WHEN** a user attempts AI generation without selecting any usable record
- **THEN** the system blocks the request and asks the user to select or create source material

### Requirement: AI context is minimal and task-specific
The system SHALL send only the fields required for the current AI task and SHALL NOT send the full journal pool by default.

#### Scenario: Generate from one entry
- **WHEN** a user generates a resume bullet from one selected entry
- **THEN** the request context is limited to that entry and the prompt required for resume bullet generation

#### Scenario: Generate weekly report
- **WHEN** a user generates a weekly report from a chosen date range or selected entries
- **THEN** the request context is limited to the selected range or entries and excludes unrelated records

### Requirement: AI output preserves fact boundaries
The system SHALL require AI outputs to distinguish usable content, missing evidence, follow-up questions, and risk notes according to the selected artifact type.

#### Scenario: Missing measurable result
- **WHEN** selected records do not contain a measurable result
- **THEN** generated content marks the missing result as a gap instead of inventing a metric

#### Scenario: Unsupported provider output
- **WHEN** a provider returns empty, malformed, or contract-incompatible output
- **THEN** the system reports the output as unusable and does not save it as a successful artifact

### Requirement: Supported artifact types are explicit
The system SHALL support follow-up questions, resume bullets, weekly reports, and interview cards as distinct AI generation tasks.

#### Scenario: Follow-up generation
- **WHEN** a user generates follow-up questions for selected records
- **THEN** the output contains questions and reasons intended to fill factual gaps

#### Scenario: Resume bullet generation
- **WHEN** a user generates a resume bullet from selected records
- **THEN** the output contains a concise bullet, missing fields, interview questions, and risk notes

#### Scenario: Weekly report generation
- **WHEN** a user generates a weekly report from multiple records
- **THEN** the output groups work into report-ready sections and marks incomplete evidence

#### Scenario: Interview card generation
- **WHEN** a user generates an interview card from selected records
- **THEN** the output contains an opening answer, possible follow-up questions, answer angles, and evidence gaps

### Requirement: AI errors are user-actionable
The system SHALL map common provider failures to clear user-facing states without exposing secrets or raw credentials.

#### Scenario: Invalid API key
- **WHEN** the provider returns an authentication or permission failure
- **THEN** the system tells the user to check provider credentials without logging or displaying the API key

#### Scenario: Rate limited provider
- **WHEN** the provider reports rate limiting
- **THEN** the system tells the user to retry later and keeps existing journal data and artifacts unchanged
