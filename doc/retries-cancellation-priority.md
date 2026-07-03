# Retries, Cancellation, and Priority

Retry transient failures:

```dart
final response = await Nexio.get<Map<String, Object?>>(
  '/status',
  retryPolicy: const RetryPolicy(
    retries: 3,
    strategy: RetryStrategy.exponential,
    delay: Duration(milliseconds: 300),
  ),
);
```

Cancel one request with Dio:

```dart
final token = CancelToken();

final future = Nexio.get<void>('/profile', cancelToken: token);
token.cancel('No longer needed');
await future;
```

Cancel by tag or group:

```dart
final profile = Nexio.get<void>('/profile', cancelTag: 'profile');
Nexio.cancelTag('profile');
await profile;

final feed = Nexio.get<void>('/feed', cancelGroup: 'home');
Nexio.cancelGroup('home');
await feed;
```

Prioritize important work:

```dart
await Nexio.get<void>(
  '/checkout/summary',
  priority: RequestPriority.high,
);
```

Identical in-flight requests are deduplicated by default. Disable it only when
the backend must receive every call:

```dart
await Nexio.post<void>(
  '/analytics',
  data: event,
  deduplicate: false,
);
```

Do not retry a non-idempotent payment or mutation unless the backend enforces
an idempotency key and defines retry behavior.
