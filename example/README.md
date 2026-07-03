# Nexio mobile example

This Android and iOS application demonstrates environment setup, typed parsing,
automatic threading, caching, per-request Chucker capture, response metrics,
and the log viewer.

## Run

```bash
flutter pub get
flutter run
```

The app uses JSONPlaceholder for its read-only user-list request. Tap **Load
users** to execute the request and use the receipt icon to open network logs.

## Test

```bash
flutter test
flutter test integration_test/nexio_runtime_test.dart -d <device-id>
```

The integration test uses a deterministic Dio adapter. It does not call an
external backend.

## Example map

- `example.md`: shortest copyable setup and requests.
- `lib/main.dart`: runnable application.
- `all_features.dart`: package-wide feature tour.
- `fintech_telecom_runtime.dart`: enterprise fintech/telecom blueprint.
- `integration_test/nexio_runtime_test.dart`: environment and isolate flow.
