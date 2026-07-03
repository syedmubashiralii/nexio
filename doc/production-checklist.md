# Production Checklist

Use this checklist with the application's backend, security, QA, and operations
owners. Package defaults cannot decide backend-specific risk.

## Environments and Transport

- [ ] Every non-local base URL uses HTTPS.
- [ ] Environment names, headers, timeouts, and regional/tenant routing are
      verified against deployment configuration.
- [ ] Runtime switching is disabled or access-controlled in production UI.
- [ ] Certificate pinning and certificate rotation are tested when required.
- [ ] Per-request base URL overrides cannot route sensitive data to an
      untrusted host.

## Authentication

- [ ] Tokens use platform-backed secure storage.
- [ ] `headersProvider` returns the latest token and session context.
- [ ] Refresh endpoint calls cannot trigger recursive refresh.
- [ ] Concurrent 401 responses run one refresh callback.
- [ ] Refresh failure and session expiry navigate only once.
- [ ] Logout while requests are in flight is covered by tests.

## Encryption and Sensitive Data

- [ ] The backend supports the selected Nexio envelope exactly.
- [ ] GCM is preferred for new contracts; legacy CBC risks are accepted and
      documented when CBC is required.
- [ ] Keys and IVs are provisioned outside source control and have a rotation
      procedure.
- [ ] TLS remains enabled even when payload encryption is used.
- [ ] Payment, PIN, OTP, KYC, identity, and token endpoints set
      `logInChucker: false`.
- [ ] Production builds follow the application's Chucker/logging policy.

## Retry and Transaction Safety

- [ ] Retryable status codes match backend behavior.
- [ ] Payment and mutation retries use server-enforced idempotency keys.
- [ ] `deduplicate` behavior is deliberate for every transaction endpoint.
- [ ] Timeout and cancellation do not show a false success state.
- [ ] Priority limits do not starve normal or low-priority work.

## Cache and Offline Storage

- [ ] Sensitive responses use `CachePolicy.networkOnly` unless encrypted local
      storage is provided by the app.
- [ ] `cacheKeyExtra` includes every API version, tenant, country, language, and
      account value that changes response meaning.
- [ ] TTL values match product freshness requirements.
- [ ] Offline queue persistence of bodies, query values, and headers is
      approved by the security owner.
- [ ] Queued operations are safe to replay later and are idempotent.
- [ ] Logout clears or invalidates app data that must not cross sessions.

## Parsing and Performance

- [ ] Large production payloads are measured on representative devices.
- [ ] `parseThresholdKb` is tuned from measurements, not guesswork.
- [ ] Typed parsers handle success and error envelope variations.
- [ ] Parser and model failures retain diagnostics without logging secrets.

## Uploads and Downloads

- [ ] File size, MIME type, and destination paths are validated by the app.
- [ ] Upload cancellation and screen disposal are tested.
- [ ] Download servers support range requests before pause/resume is exposed.
- [ ] Storage permissions and free-space failures have user-visible recovery.

## Observability

- [ ] Event subscriptions are cancelled with their owner lifecycle.
- [ ] Health snapshots are sent only to the approved telemetry service.
- [ ] Metrics do not include tokens, payloads, or high-cardinality query data.
- [ ] Unauthorized and refresh events do not produce duplicate analytics.

## Release Verification

- [ ] `dart format --output=none --set-exit-if-changed lib test example`
- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] Example analysis and widget tests
- [ ] Android debug build
- [ ] iOS simulator build
- [ ] Android or iOS integration test on a device/simulator
- [ ] `dart doc` generation
- [ ] `flutter pub outdated` review
- [ ] `dart pub publish --dry-run` with zero warnings
- [ ] Current `pana` report reviewed
