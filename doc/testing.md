# Testing Guide

Test networking behavior without depending on a real backend. Nexio accepts a
custom Dio instance or an environment-specific `dioFactory`, so tests can use a
deterministic `HttpClientAdapter`.

If a test imports Dio adapter types directly, declare `dio` as a direct
development dependency in the consuming project.

## Deterministic Adapter

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
```

## Typed Request Test

```dart
test('resolves the environment and parses typed data', () async {
  final dio = Dio()
    ..httpClientAdapter = FakeAdapter((options) {
      expect(options.uri.toString(), 'https://dev.example.com/users');
      return ResponseBody.fromString(
        '[{"id":1}]',
        200,
        headers: const {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

  Nexio.initialize(
    environments: const {
      'dev': NexioEnvironment(baseUrl: 'https://dev.example.com'),
    },
    initialEnvironment: 'dev',
    dio: dio,
  );

  final response = await Nexio.get<List<int>>(
    '/users',
    parser: (input) async => (input! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map((item) => item['id']! as int)
        .toList(),
  );

  expect(response.data, [1]);
});
```

## Retry Test

Count adapter calls and use `Duration.zero` so the test stays fast:

```dart
var attempts = 0;
final dio = Dio()
  ..httpClientAdapter = FakeAdapter((_) {
    attempts += 1;
    return ResponseBody.fromString(
      attempts < 3 ? 'temporary' : '{"ok":true}',
      attempts < 3 ? 503 : 200,
      headers: const {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  });

Nexio.initialize(
  environments: const {
    'test': NexioEnvironment(baseUrl: 'https://test.example.com'),
  },
  initialEnvironment: 'test',
  dio: dio,
  retryPolicy: const RetryPolicy(
    retries: 2,
    strategy: RetryStrategy.fixed,
    delay: Duration.zero,
  ),
);
```

Assert that the final response succeeds and `attempts == 3`.

## Isolate Parsing Test

Force background JSON decoding instead of relying on payload size:

```dart
final response = await Nexio.get<List<int>>(
  '/large-payload',
  threadMode: ThreadMode.background,
  parser: parseIds,
);
```

Keep reusable parser functions top-level or static. Nexio moves built-in JSON
decoding with `compute`; the custom parser runs after decoding and can remain
async.

## Authentication Coordination Test

Return HTTP 401 for an expired dynamic header, start two requests together,
delay the refresh callback, then assert:

- refresh ran once;
- both requests retried with fresh headers;
- both responses completed;
- refresh failure calls `onSessionExpired` and does not loop.

The package test suite contains a complete version of this scenario in
[`test/nexio_test.dart`](../test/nexio_test.dart).

## Mobile Integration Test

The example host includes Android and iOS targets:

```bash
cd example
flutter devices
flutter test integration_test/nexio_runtime_test.dart -d <device-id>
```

The test verifies environment switching, one Dio per environment, and forced
background decoding with a deterministic transport adapter.

## Package Verification

```bash
flutter analyze
flutter test

cd example
flutter analyze
flutter test
```
