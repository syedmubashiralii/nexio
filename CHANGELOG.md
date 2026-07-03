## 0.1.0

### Added

- Added arbitrary named environments with runtime switching and per-request
  base URL overrides.
- Added Dio-powered GET, POST, PUT, PATCH, DELETE, multipart upload, and
  pause/resume/cancel download APIs.
- Added AES-CBC and AES-GCM request/response envelopes with pluggable ciphers.
- Added typed JSON, string, bytes, XML, and custom parsing with configurable
  background-isolate decoding.
- Added fixed and exponential retries, memory and disk caches, TTL policies,
  offline request replay, cancellation, request priority, and deduplication.
- Added conditional Chucker capture, lifecycle events, response metrics, and
  privacy-safe aggregate network health monitoring.
- Added backend-agnostic authentication hooks with dynamic headers,
  single-flight refresh coordination, and session-expiry callbacks.

### Architecture

- Added stable Dio pooling per environment and app-owned interceptor factories.
- Moved context headers and CBC/GCM transforms into built-in Dio interceptors.
- Added cache namespaces for API versions, tenants, countries, locales, and
  accounts.
- Split request execution, authentication coordination, and Dio-pool runtime
  responsibilities into focused implementation files.

### Documentation

- Added a runnable Android/iOS example, a complete feature tour, a
  fintech/telecom blueprint, focused adoption guides, and a mobile integration
  test.

### Verification

- Added unit, widget, documentation-consistency, and integration test targets.
- Added Android, iOS, API-documentation, pub archive, and pub-point preflight
  commands for release maintainers.
