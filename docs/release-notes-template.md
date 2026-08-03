# Release Notes Template

## Daily Asking vX.Y.Z

### User-visible changes

- 

### Verification evidence

- `openspec validate production-v1-prd --strict`: 
- `flutter analyze`: 
- `flutter test`: 
- `flutter build apk --release`: 
- APK artifact path or GitHub Actions artifact name: 

### Privacy model

- Local-first journal storage.
- BYOK OpenAI-compatible provider configuration.
- Real AI calls require outbound disclosure and user confirmation.
- API Key must not enter logs, records, exports, migration packages, or repository files.

### Signing posture

- APK signing type: debug signing / local release signing / CI-managed signing.
- If debug signing: mark this as a GitHub preview release, not app-store-ready production.

### Known limitations

- No cloud sync account system.
- No app-store release package.
- No production official Worker gateway path.

### Upgrade notes

- 
