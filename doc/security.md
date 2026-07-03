# Security Guide

Nexio provides transport orchestration and optional payload encryption. A
secure application still needs a backend threat model, TLS, secure key delivery,
safe local storage, log controls, and transaction idempotency.

## TLS Is Required

Use HTTPS for every non-local environment. AES-CBC or AES-GCM payload envelopes
do not replace TLS: TLS protects server identity, request metadata, headers,
paths, and transport integrity.

Use `dioFactory` when your application needs certificate pinning or a custom
`HttpClientAdapter`:

```dart
Nexio.initialize(
  environments: environments,
  initialEnvironment: 'production',
  dioFactory: (name, environment) {
    final dio = Dio();
    dio.httpClientAdapter = buildPinnedAdapter(name, environment);
    return dio;
  },
);
```

Certificate policy remains app-owned because it depends on deployment and
rotation procedures.

## Encryption Modes

### AES-GCM

AES-GCM provides confidentiality and authentication. Nexio generates a nonce
for each encrypted request and sends a JSON-safe envelope containing `payload`,
`nonce`, `mac`, `contentType`, `mode`, and `nexioEncrypted`.

Prefer GCM for new backend contracts.

### AES-CBC

The built-in CBC implementation uses the configured IV and does not add a
message authentication code. A fixed IV can reveal repeated plaintext patterns,
and unauthenticated CBC cannot detect every ciphertext modification.

Use CBC only when integrating with a legacy backend contract that requires this
exact behavior. Prefer a custom authenticated cipher or GCM for new systems.

### Secret Lengths

- CBC and GCM keys must decode to 16, 24, or 32 bytes.
- A CBC IV must decode to exactly 16 bytes.
- Values may be UTF-8 strings or base64 text.

Invalid configuration throws `NexioEncryptionException`.

## Key Provisioning

Do not commit production keys, place them in README snippets, or assume a
compile-time constant is secret. Mobile binaries can be inspected.

Provision keys through an app-owned secure flow, store them using platform
security facilities, rotate them with the backend, and initialize Nexio only
after the required material is available. If keys are device- or session-bound,
implement a custom `NexioCipher` rather than forcing them into global static
configuration.

## Chucker and Logs

Use the secure default:

```dart
enableChucker: true,
defaultLogInChucker: false,
```

Then opt in only non-sensitive debug endpoints:

```dart
await Nexio.get('/catalog', logInChucker: true);
await Nexio.post('/payments', data: payment, logInChucker: false);
```

Never capture PIN, OTP, card, payment, identity, biometric, KYC, access-token,
or refresh-token payloads. Disable inspection tooling in production builds
according to your application policy.

App-owned interceptors run before Nexio encryption. They must not print or
export plaintext sensitive bodies.

## Cache Storage

Disk cache entries contain decrypted response data in the application support
directory. Do not use disk caching for secrets or regulated personal data unless
the application adds an appropriate encrypted storage layer.

For sensitive endpoints use:

```dart
cachePolicy: CachePolicy.networkOnly,
```

Cache keys are hashes of request inputs, but hashing the key does not encrypt
the cached response body.

## Offline Queue Storage

When enabled, the offline queue stores a JSON-safe request body, query values,
and headers in the application support directory before replay. This can
include authorization or personal data.

Do not enable the global offline queue for payment, authentication, identity,
or other sensitive operations unless that persistence is explicitly acceptable
to the application threat model. Avoid queueing non-idempotent operations.

## Transaction Safety

Encryption does not prevent duplicate business operations. For payments and
wallet actions:

- use a backend-enforced idempotency key;
- set `deduplicate: false` when every user action must reach the backend;
- set retries to zero unless the idempotency contract makes retry safe;
- disable Chucker and disk cache;
- cancel by group only when cancellation semantics are understood.

## Security Review Checklist

- HTTPS is mandatory outside local development.
- Certificate policy and rotation are documented.
- GCM is preferred for new encrypted payload contracts.
- Keys are provisioned and rotated outside source control.
- Sensitive requests opt out of Chucker and cache.
- Offline queue persistence is approved for the stored fields.
- Auth/session headers are not written to logs.
- Payment and mutation retries are protected by server idempotency.
- Backend envelope compatibility is covered by integration tests.
