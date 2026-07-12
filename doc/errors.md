# Error Handling

Nexio preserves typed HTTP responses while keeping configuration, cache,
offline, and encryption failures distinguishable.

## Exception Reference

| Type | Meaning | Typical action |
|---|---|---|
| `NexioNotInitializedException` | A request was made before `Nexio.initialize` | Initialize once during app startup |
| `NexioEnvironmentException` | Environment is missing or has an invalid absolute base URL | Fix configuration or selected name |
| `NexioCacheMissException` | `cacheOnly` found no valid entry | Show unavailable state or choose another policy |
| `NexioHttpException<T>` | Server returned a non-success status | Inspect the typed `response` and apply domain rules |
| `NexioOfflineQueuedException` | Request was persisted for later replay | Treat it as queued, not completed |
| `NexioOfflineException` | Active connectivity verification found no reachable network | Show offline state or retry later |
| `NexioOfflineQueueSerializationException` | Replay data is not JSON-safe | Remove unsupported values or disable replay |
| `NexioSessionExpiredException` | Protected traffic is blocked after auth expiry | Establish a new session, then reset the auth gate |
| `NexioEncryptionException` | Cipher configuration or encrypted envelope is invalid | Stop the request and verify backend/key contract |
| `DioException` | Transport, timeout, cancellation, or adapter failure | Inspect `type`, retry policy, and connectivity |
| Parser error | Decoded data does not match `T` or the parser throws | Fix the response/parser contract |

## Typed HTTP Failures

`NexioHttpException<T>` carries the parsed `NexioResponse<T>`:

```dart
try {
  await Nexio.get<ApiError>(
    '/protected-resource',
    parser: ApiError.parse,
  );
} on NexioHttpException<ApiError> catch (error) {
  final response = error.response;
  print(response.statusCode);
  print(response.data.code);
  print(response.metrics.totalDuration);
}
```

The parser must be able to parse the error body's shape. If success and error
payloads are structurally different, request a shared envelope type or handle
the body with a parser that understands both forms.

## Offline Queue Is Not Success

```dart
try {
  await Nexio.post<void>(
    '/events',
    data: event,
    queueWhenOffline: true,
  );
} on NexioOfflineQueuedException catch (error) {
  showQueuedState(error.queueId);
}
```

The original operation has not completed. Replay can still fail and reports
through the global event bus.

## Cancellation

```dart
try {
  await Nexio.get<void>('/slow', cancelToken: token);
} on DioException catch (error) {
  if (CancelToken.isCancel(error)) {
    return;
  }
  rethrow;
}
```

Nexio also emits `NexioRequestCancelledEvent`.

## Central Observation

Use global events for diagnostics, not to hide local error handling:

```dart
final subscription = Nexio.events.listen((event) {
  if (event case NexioRequestFailedEvent()) {
    diagnostics.record(event.error, event.stackTrace);
  }
});
```

Callers should still handle errors when the UI or business flow needs a
specific recovery state.

## Recommended Pattern

1. Handle typed backend errors closest to the feature.
2. Treat cancellation as an expected lifecycle result.
3. Treat an offline-queued request as pending work.
4. Route auth expiry through one app-owned session coordinator.
5. Use global events and health aggregates for diagnostics.
6. Do not convert every failure into `null`; preserve context and stack traces.
