# Daily Asking (晨昏证据图谱)

> A local-first workplace evidence growth companion: record one real thing every day, turn traces into evidence, and turn evidence into outcomes.

[中文](README.md) · [日本語](README.ja.md) · [MIT License](LICENSE)

Daily Asking is a **local-first** mobile app. It starts from "one real thing that happened today", uses structured follow-up questions to turn scattered work notes into a searchable, reusable **workplace evidence graph**, and generates resume bullet points, weekly reports, or interview question cards whenever you need them.

**Core belief: your data is yours, AI is optional.**

---

## ✨ Features

- **Local-first, private by default**: all records are stored on your device. No accounts, no login, no subscription, no cloud sync, no telemetry.
- **One question per day**: after you save a record, a local rules engine asks at most one "most worth answering" question (result / context / action / blocker / personal contribution) to turn scratch notes into complete evidence.
- **Evidence graph**: browse all records by time and tags, with full-text search and 7-day / 30-day filters, and a completeness indicator at a glance.
- **Studio (optional AI)**: select one or more evidence entries and generate resume bullet points / weekly reports / interview question cards.
- **BYOK (Bring Your Own Key)**: AI calls use your own API key (OpenAI-compatible). The key is stored only in isolated local storage, never echoed in the UI; every real call shows an **outbound disclosure** and only sends the minimal fields you selected after you confirm.
- **Theme switching**: system / light / dark.

## 🚀 Getting Started

### Prerequisites

- Flutter 3.44+ (Dart 3.12+)
- Android SDK (for building the Android app)

### Run

```bash
flutter pub get
flutter run
```

### Test and check

```bash
flutter analyze
flutter test
flutter build apk --release
```

## 📦 Installation

An Android build is available as `app-release.apk` (not committed to the repo). You can also build it yourself with the steps above.

## 🧭 App Tour

| Page | Description |
| --- | --- |
| Today | Quickly record one real thing and answer local follow-up questions |
| Evidence | Search / filter all evidence records and view completeness |
| Studio | Select evidence to generate resume / weekly report / interview cards |
| Settings | Theme, optional AI (BYOK) configuration, privacy notes |

## 🏗️ Architecture

- `lib/core/` — domain models, storage abstraction, optional LLM client
- `lib/evidence/` — evidence records, follow-up engine, evidence graph
- `lib/journal/` — today page
- `lib/artifacts/` — studio and artifact management
- `lib/settings/` — settings and BYOK configuration
- `lib/app/` — app shell and global state

See [docs/architecture.md](docs/architecture.md).

## 🔒 Security

- Logs never record API keys, entry content, or full prompts.
- Real AI calls only send the minimal fields you selected, after an outbound confirmation.
- To report a security issue, see [SECURITY.md](SECURITY.md).

## 🤝 Contributing

Issues and pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## 📄 License

[MIT License](LICENSE) © 2026 greatleo31