## Purpose

Defines the local-first journal experience that lets users capture, manage, search, filter, and export real work records without requiring AI configuration.

## ADDED Requirements

### Requirement: Local journal entries are manageable without AI
The system SHALL allow users to create, view, edit, and delete local journal entries without requiring network access or AI provider configuration.

#### Scenario: Create entry offline
- **WHEN** a user saves a journal entry while no AI provider is configured
- **THEN** the entry is stored locally and appears in the journal list

#### Scenario: Edit existing entry
- **WHEN** a user updates the task, context, action, result, blocker, tags, or date of an existing entry
- **THEN** the updated entry replaces the previous version while retaining a stable entry identity

#### Scenario: Delete entry
- **WHEN** a user confirms deletion of an entry
- **THEN** the entry no longer appears in the active journal list or future AI source selection

### Requirement: Journal fields preserve evidence semantics
The system SHALL keep journal fields semantically distinct so later AI generation can distinguish task, context, action, result, blocker, tags, and dates.

#### Scenario: Missing optional evidence
- **WHEN** a user saves an entry with only the task field filled
- **THEN** the system stores the entry and treats the missing context, action, result, blocker, and tags as absent evidence

#### Scenario: Update timestamps
- **WHEN** a user modifies a saved entry
- **THEN** the system records that the entry was updated later than it was created

### Requirement: Journal list supports search and filtering
The system SHALL allow users to find local entries by keyword and narrow the list by date range without sending data to any external service.

#### Scenario: Keyword search
- **WHEN** a user searches for text that appears in a saved entry
- **THEN** the journal list shows matching entries and preserves their date ordering

#### Scenario: Empty search result
- **WHEN** no local entry matches the current search or filter
- **THEN** the system shows an empty state that does not imply data loss

### Requirement: Journal export is explicit and portable
The system SHALL allow users to export selected or all local entries in human-readable Markdown and structured JSON formats.

#### Scenario: Export selected entries
- **WHEN** a user exports selected entries
- **THEN** the exported content contains only those entries and their journal fields

#### Scenario: Export excludes secrets
- **WHEN** a user exports journal data after configuring an AI provider
- **THEN** the exported content excludes API keys, secure-storage aliases, hidden model credentials, and runtime logs

### Requirement: Local data failure is visible
The system SHALL show recoverable error states when local journal data cannot be read, parsed, saved, or exported.

#### Scenario: Corrupt local data
- **WHEN** stored journal data cannot be parsed
- **THEN** the system reports that local records could not be loaded and avoids overwriting the stored payload automatically

#### Scenario: Export failure
- **WHEN** export cannot be completed
- **THEN** the system reports the failure and keeps the original journal data unchanged
