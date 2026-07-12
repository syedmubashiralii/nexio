# Troubleshooting

## `Call Nexio.initialize(...) before making requests`

Initialize Nexio before any service, provider, controller, or background task
can issue a request. Keep initialization in the application bootstrap path.

## Unknown or Invalid Environment

`NexioEnvironmentException` means the selected name is absent, the base URL is
empty, or the URL is not absolute.

```dart
Nexio.switchEnvironment('production');
```

The string must exactly match a key supplied to `environments`.

## AES Configuration Failure

- CBC/GCM key: 16, 24, or 32 decoded bytes.
- CBC IV: exactly 16 decoded bytes.
- Values can be UTF-8 or base64.

If the key is configured but the server does not return a Nexio-compatible
envelope, response decryption leaves a non-envelope body unchanged. Verify the
backend contract rather than silently treating encrypted text as a typed model.

## Parser Type Error

The parser receives decrypted, JSON-decoded data. Inspect the actual response
shape and avoid unsafe casts when a backend can return multiple envelopes.

```dart
parser: (input) async {
  if (input is! Map) {
    throw FormatException('Expected an object response.');
  }
  return User.fromJson(Map<String, Object?>.from(input));
},
```

## Loader Does Not Appear

Provide either a request `context` or a global `navigatorKey`:

```dart
final navigatorKey = GlobalKey<NavigatorState>();

Nexio.initialize(
  environments: environments,
  initialEnvironment: 'dev',
  navigatorKey: navigatorKey,
);

MaterialApp(navigatorKey: navigatorKey);
```

For flows that perform location, permission, or database work before the API
call, let the screen own the loader from the beginning and use
`showLoader: false` for the Nexio request.

## Chucker Screen Does Not Open

Set `enableChucker: true` during initialization and attach
`ChuckerFlutter.navigatorKey` to `MaterialApp`. A per-request
`logInChucker: false` prevents capture but does not disable the Chucker screen.

## `cacheOnly` Throws

`CachePolicy.cacheOnly` intentionally throws `NexioCacheMissException` when no
unexpired entry exists. Seed the cache with `cacheFirst`/`networkFirst`, choose a
different policy, or handle the miss as an offline state.

## Offline Request Never Replays

Confirm that:

- `offlineQueueEnabled` is true;
- the request sets `queueWhenOffline: true`;
- the failure is a Dio connection error;
- connectivity later emits an online state;
- request data is JSON-safe;
- the endpoint accepts delayed replay;
- the current dynamic credentials are valid when replay begins.

Replay failures remain queued and emit `NexioRequestFailedEvent`.
Nexio preserves environment and encryption metadata and regenerates dynamic
auth headers instead of persisting them.

## Authenticated Requests Are Blocked

`NexioSessionExpiredException` means an auth decision expired the session or a
refresh failed. Anonymous sign-in and public calls can continue with
`authMode: NexioAuthMode.anonymous`. Save the new session first, then call
`Nexio.resetAuthSession()`.

## Background Parser Fails to Cross an Isolate

An `isolateParser` must be a top-level or static function. Avoid closures that
capture controllers, repositories, contexts, ports, or plugin objects. Return a
plain isolate-sendable model graph. Use a regular `parser` when those constraints
do not fit the endpoint.

## Download Resume Restarts or Fails

Resume requires an existing partial file and server support for the `Range`
header. If the server ignores range requests, delete the partial destination and
start again.

## Integration Test Reports No Device

Start an Android emulator, connect an Android device, or boot an iOS simulator:

```bash
flutter devices
flutter test integration_test/nexio_runtime_test.dart -d <device-id>
```

An Android/iOS build can verify compilation, but it does not replace executing
the integration test on a device or simulator.

## Requests Retry Unexpectedly

Inspect the global and per-request `RetryPolicy`. The default global policy has
zero retries. A request override replaces it. Avoid retries for non-idempotent
mutations unless the backend enforces idempotency.

## Environment Changed During a Queued Request

Nexio captures the environment when the request is scheduled. Switching affects
future requests; already queued work continues with its captured environment.
