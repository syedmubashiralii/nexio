# Contributing to Nexio

Contributions should preserve Nexio's role as a readable networking runtime,
not turn it into a backend-specific SDK.

## Before Opening a Change

- Search existing issues before opening a new report or proposal.
- Describe the application problem and why it belongs in a general runtime.
- Keep token formats, endpoints, navigation, and business rules app-owned.
- Avoid adding abstractions unless they remove demonstrated complexity.

## Development Setup

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test example
flutter analyze
flutter test
```

Verify the example application:

```bash
cd example
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --no-codesign
```

Run the device integration test when an Android/iOS target is available:

```bash
flutter test integration_test/nexio_runtime_test.dart -d <device-id>
```

## Public API Changes

- Add DartDoc to every public declaration and parameter.
- Add focused tests for success, failure, cancellation, and lifecycle cleanup.
- Update README, relevant guides, examples, and changelog together.
- Preserve null safety and strong typing.
- Explain breaking changes and provide migration instructions.

## Pull Request Checklist

- [ ] Change is backend-agnostic.
- [ ] Public API documentation is complete.
- [ ] Tests demonstrate the behavior.
- [ ] Examples compile and use supported APIs.
- [ ] `flutter analyze` and `flutter test` pass.
- [ ] Android and iOS compatibility are considered.
- [ ] Sensitive data is not printed, cached, or queued unintentionally.
- [ ] Changelog describes user-visible behavior.

## Security

Do not open a public issue containing credentials, tokens, encryption material,
personal data, or an unpatched vulnerability. Follow [SECURITY.md](SECURITY.md).
