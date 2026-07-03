# Nexio examples

Nexio is initialized once, then every request uses the selected environment,
interceptor pipeline, parser, and lifecycle policy.

## Initialize

```dart
import 'package:flutter/material.dart';
import 'package:nexio/nexio.dart';

void main() {
  Nexio.initialize(
    environments: const {
      'dev': NexioEnvironment(baseUrl: 'https://dev.example.com'),
      'production': NexioEnvironment(baseUrl: 'https://api.example.com'),
    },
    initialEnvironment: 'dev',
    navigatorKey: ChuckerFlutter.navigatorKey,
    enableChucker: true,
    defaultLogInChucker: false,
    defaultThreadMode: ThreadMode.auto,
    parseThresholdKb: 64,
  );

  runApp(const MyApp());
}
```

## Typed GET

```dart
final response = await Nexio.get<List<Map<String, Object?>>>(
  '/users',
  cachePolicy: CachePolicy.cacheFirst,
  logInChucker: true,
  parser: (input) async {
    return (input! as List<Object?>)
        .map((item) => Map<String, Object?>.from(item! as Map))
        .toList();
  },
);

print(response.data);
print(response.metrics.networkDuration);
print(response.metrics.parseDuration);
```

## Secure POST

```dart
final response = await Nexio.post<Map<String, Object?>>(
  '/payments',
  data: const {'amountMinor': 2500, 'currency': 'USD'},
  headers: const {'X-Idempotency-Key': 'payment-unique-id'},
  encryptionMode: EncryptionMode.aesGcm,
  retryPolicy: const RetryPolicy(retries: 0),
  priority: RequestPriority.high,
  deduplicate: false,
  logInChucker: false,
  parser: (input) async => Map<String, Object?>.from(input! as Map),
);
```

Configure `EncryptionConfig` during initialization before selecting CBC or GCM.
Production encryption material must come from app-owned secure provisioning and
must match the backend envelope contract.

## Runtime Environment Switch

```dart
Nexio.switchEnvironment('production');

final response = await Nexio.get<Map<String, Object?>>(
  '/health',
  parser: (input) async => Map<String, Object?>.from(input! as Map),
);
```

## More Examples

- [`lib/main.dart`](lib/main.dart): runnable Android/iOS application.
- [`all_features.dart`](all_features.dart): copyable examples for every major
  package feature.
- [`fintech_telecom_runtime.dart`](fintech_telecom_runtime.dart): auth,
  transaction, cache-versioning, and loader patterns for enterprise apps.
- [`integration_test/nexio_runtime_test.dart`](integration_test/nexio_runtime_test.dart):
  environment switching and forced background JSON decoding.

Run the application:

```bash
cd example
flutter pub get
flutter run
```

Run its tests:

```bash
flutter test
flutter test integration_test/nexio_runtime_test.dart -d <device-id>
```
