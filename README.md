# Nexio

**The networking runtime for Flutter.**

Nexio is a production-grade networking package for Flutter applications on
Android and iOS. It uses [Dio](https://pub.dev/packages/dio) as its HTTP engine
and adds the coordination layer that large applications repeatedly rebuild:
runtime environments, interceptor-driven context, encryption, typed parsing,
isolate-aware JSON decoding, retries, caching, offline replay, cancellation,
uploads, downloads, request scheduling, logging, and monitoring.

Nexio is not a custom HTTP implementation and it does not hide Dio from
advanced use cases. It provides one predictable request lifecycle while keeping
backend-specific policy in your application.

## Use Nexio When

- your app has development, QA, staging, regional, tenant, or production APIs;
- headers and session context must be evaluated before every request;
- large JSON responses can cause dropped Flutter frames;
- payment, telecom, self-care, marketplace, or enterprise flows need explicit
  retry, cache, cancellation, priority, and idempotency decisions;
- you need CBC/GCM payload envelopes that match a cooperating backend;
- multiple callers should share an identical in-flight request;
- you want request timing, lifecycle events, network state, and optional
  Chucker inspection from one runtime.

## What Remains App-Owned

Nexio deliberately does not define your token format, refresh endpoint, secure
storage, certificate-pinning policy, analytics backend, route navigation, or UI
design. It provides hooks so those decisions remain testable and specific to
your backend.

## Features

| Area | Included |
|---|---|
| Transport | Dio-powered GET, POST, PUT, PATCH, DELETE, multipart upload, and file download |
| Environments | Any number of named environments, runtime switching, per-request base URL override, stable Dio pool per environment |
| Interceptors | Built-in context, encryption, logging, and conditional Chucker interceptors plus app-owned factories |
| Encryption | AES-CBC, AES-GCM, no encryption, custom ciphers, and backend wire-format adapters |
| Parsing | JSON, string, bytes, XML, custom parsers, registered typed models, automatic background JSON decoding |
| Resilience | Fixed/exponential retries, cancellation, priorities, concurrency limits, in-flight deduplication |
| Caching | Memory and disk cache, TTL, network-only, cache-only, cache-first, and network-first policies |
| Connectivity | Online/offline streams and optional persisted offline request replay |
| Transfers | Multipart progress and cancellation; download progress, pause, resume, and cancel |
| UI hooks | Optional global/per-request loaders without imposing an app design |
| Observability | Lifecycle events, console/in-memory logs, Chucker, response timing, and aggregate health outcomes |

## Request Pipeline

```text
Nexio call
  -> priority scheduler and in-flight deduplication
  -> environment URL and context headers
  -> app interceptors
  -> optional request encryption
  -> Dio asynchronous network I/O
  -> optional response decryption
  -> automatic main/background JSON decoding
  -> typed parser
  -> cache, events, health counters, and timing metrics
```

## Installation

```yaml
dependencies:
  nexio: ^0.1.0
```

```bash
flutter pub get
```

Import the single public library:

```dart
import 'package:nexio/nexio.dart';
```

## 60-Second Start

Initialize once before the app starts making requests:

```dart
void main() {
  Nexio.initialize(
    environments: const {
      'dev': NexioEnvironment(baseUrl: 'https://dev.example.com'),
      'production': NexioEnvironment(baseUrl: 'https://api.example.com'),
    },
    initialEnvironment: 'dev',
  );

  runApp(const MyApp());
}
```

Make a typed request:

```dart
final response = await Nexio.get<List<User>>(
  '/users',
  parser: parseUsers,
);

final users = response.data;
print('Loaded ${users.length} users');
print('Total time: ${response.metrics.totalDuration}');

Future<List<User>> parseUsers(Object? input) async {
  final items = input! as List<Object?>;
  return items
      .cast<Map<String, Object?>>()
      .map(User.fromJson)
      .toList();
}
```

`NexioResponse<T>` also exposes status, headers, cache origin, Dio request
options, and network/decrypt/parse/total timing metrics.

## Complete Initialization

All settings have conservative defaults. Enable only the capabilities your app
uses:

```dart
Nexio.initialize(
  environments: const {
    'local': NexioEnvironment(baseUrl: 'http://10.0.2.2:8080'),
    'qa-east': NexioEnvironment(
      baseUrl: 'https://qa-east.example.com',
      headers: {'X-Region': 'east'},
    ),
    'uat': NexioEnvironment(baseUrl: 'https://uat.example.com'),
    'production': NexioEnvironment(baseUrl: 'https://api.example.com'),
  },
  initialEnvironment: 'qa-east',
  defaultHeaders: const {'Accept': Headers.jsonContentType},
  loggerEnabled: true,
  enableChucker: true,
  defaultLogInChucker: false,
  defaultThreadMode: ThreadMode.auto,
  parseThresholdKb: 64,
  retryPolicy: const RetryPolicy(retries: 2),
  cacheConfig: const CacheConfig(
    defaultTtl: Duration(minutes: 5),
  ),
  maxConcurrentRequests: 6,
  offlineQueueEnabled: true,
  networkConfig: NexioNetworkConfig(
    connectivityProbe: checkBackendReachability,
  ),
  interceptorFactories: [
    () => CorrelationIdInterceptor(),
  ],
);
```

## Environments

Environment names belong to your application. Switch without reinitializing:

```dart
Nexio.switchEnvironment('production');

print(Nexio.currentEnvironment);
print(Nexio.currentEnvironmentConfig.baseUrl);
```

Override one request without creating another Dio instance:

```dart
final response = await Nexio.get<Map<String, Object?>>(
  '/status',
  baseUrlOverride: 'https://status.example.com',
  parser: parseMap,
);
```

Nexio captures the selected environment when a request enters the scheduler.
Later environment changes affect future calls, not already queued calls.

## Request Configuration

```dart
final response = await Nexio.post<PaymentReceipt>(
  '/payments',
  data: payment.toJson(),
  headers: {'X-Idempotency-Key': payment.idempotencyKey},
  encryptionMode: EncryptionMode.aesGcm,
  threadMode: ThreadMode.auto,
  retryPolicy: const RetryPolicy(retries: 0),
  cachePolicy: CachePolicy.networkOnly,
  priority: RequestPriority.high,
  deduplicate: false,
  cancelGroup: 'payments',
  showLoader: true,
  logInChucker: false,
  parser: PaymentReceipt.parse,
);
```

Use `Nexio.request<T>` when the HTTP method or advanced Dio options are chosen
dynamically.

## Registered Parsers

Register parsers used across many endpoints:

```dart
Nexio.registerParser<User>((input) async {
  return User.fromJson(Map<String, Object?>.from(input! as Map));
});

final user = (await Nexio.get<User>('/me')).data;
```

The parser receives already decrypted and JSON-decoded data.

## Await and Isolates

`await Nexio.get(...)` does not block Flutter's UI isolate. Dio performs
asynchronous network I/O; `await` suspends only the current async function while
the event loop continues rendering frames and processing input.

Isolates solve a different problem: CPU work. Nexio's `ThreadMode.auto` measures
raw JSON size and uses Flutter's `compute` for decoding when the configured
threshold is crossed. For very large typed responses, `isolateParser` moves
JSON decoding and model construction together. Its callback must be top-level
or static so Dart can send it to an isolate.

```dart
final catalog = await Nexio.get<List<Item>>(
  '/large-catalog',
  threadMode: ThreadMode.auto,
  parseThresholdKb: 32,
  isolateParser: Item.parseListFromSource,
);
```

The network wait and the isolate result are both `Future`s, so callers correctly
use `await` for both. See the [threading guide](doc/threading.md).

## Encryption

Configure backend-compatible keys centrally and select a mode per request:

```dart
Nexio.initialize(
  environments: environments,
  initialEnvironment: 'production',
  encryptionConfig: EncryptionConfig(
    aesCbcKey: secureConfig.cbcKey,
    aesCbcIv: secureConfig.cbcIv,
    aesGcmKey: secureConfig.gcmKey,
  ),
);

final receipt = await Nexio.post<PaymentReceipt>(
  '/payments',
  data: payment.toJson(),
  encryptionMode: EncryptionMode.aesGcm,
  logInChucker: false,
  parser: PaymentReceipt.parse,
);
```

Request flow is serialize then encrypt then send. Response flow is receive then
decrypt then parse. Local payload encryption complements TLS; it does not
replace TLS. Never hardcode production secrets in source code. See the
[encryption guide](doc/encryption.md) and [security guide](doc/security.md).

## Authentication Hooks

Nexio can coordinate one app-owned refresh operation while other protected
requests wait:

```dart
authConfig: NexioAuthConfig(
  headersProvider: () => {
    'Authorization': 'Bearer ${session.accessToken}',
    'X-Gateway-Token': session.gatewayToken,
  },
  decide: (signal) {
    if (signal.statusCode == 401) {
      return NexioAuthDecision.refreshAndRetry;
    }
    return NexioAuthDecision.proceed;
  },
  refresh: (_) => session.refreshTokens(),
  onSessionExpired: (_) => session.expire(),
),
```

Your callback owns credentials, storage, endpoint selection, and token parsing.
See [authentication hooks](doc/authentication.md).

Mark sign-in, registration, public configuration, and refresh traffic as
anonymous so dynamic auth headers and the expired-session gate are skipped:

```dart
final config = await Nexio.get<Map<String, Object?>>(
  '/public/config',
  authMode: NexioAuthMode.anonymous,
  parser: parseMap,
);

Nexio.resetAuthSession(); // Call only after a new session is established.
```

## Retries, Cache, Priority, and Deduplication

```dart
final offers = await Nexio.get<List<Offer>>(
  '/offers',
  retryPolicy: const RetryPolicy(
    retries: 3,
    strategy: RetryStrategy.exponential,
  ),
  cachePolicy: CachePolicy.networkFirst,
  cacheTtl: const Duration(minutes: 15),
  cacheKeyExtra: {
    'apiVersion': offersVersion,
    'country': countryCode,
  },
  priority: RequestPriority.normal,
  parser: Offer.parseList,
);
```

Identical in-flight requests are deduplicated by default. Disable deduplication
for analytics or transaction calls that the backend must receive separately.
Do not retry non-idempotent operations unless the backend contract and an
idempotency key make the retry safe.

## Cancellation

```dart
final token = CancelToken();

final request = Nexio.get<User>(
  '/profile',
  cancelToken: token,
  cancelTag: 'profile',
  cancelGroup: 'account',
);

token.cancel('Screen closed');
Nexio.cancelTag('profile');
Nexio.cancelGroup('account');
```

## Uploads and Downloads

```dart
final uploaded = await Nexio.upload<Map<String, Object?>>(
  '/documents',
  files: const [
    NexioUploadFile(
      fieldName: 'document',
      path: '/path/to/document.pdf',
      contentType: 'application/pdf',
    ),
  ],
  onSendProgress: (sent, total) => print('$sent / $total'),
  logInChucker: false,
  parser: parseMap,
);
```

```dart
final task = Nexio.download(
  '/reports/monthly.pdf',
  destinationPath: '/path/to/monthly.pdf',
  onProgress: (received, total) => print('$received / $total'),
);

await task.pause();
await task.resume();
final savedPath = await task.completed;
```

Download resume requires server support for HTTP range requests.

## Logging and Chucker

Enable Chucker capability globally and opt in only safe requests:

```dart
Nexio.initialize(
  environments: environments,
  initialEnvironment: 'qa',
  enableChucker: true,
  defaultLogInChucker: false,
);

await Nexio.get('/catalog', logInChucker: true);
await Nexio.post('/payments', data: payment, logInChucker: false);
```

Attach `ChuckerFlutter.navigatorKey` to `MaterialApp`, then call
`Nexio.showLogs(context)`. Keep payment, PIN, OTP, identity, and KYC traffic out
of inspection tools.

## Events, Connectivity, and Health

```dart
final eventSubscription = Nexio.events.listen((event) {
  switch (event) {
    case NexioRequestFailedEvent():
      reportFailure(event);
    case NexioUnauthorizedEvent():
      openSignInOnce();
    default:
      break;
  }
});

final onlineSubscription = Nexio.online.listen((_) => retryVisibleWork());
```

`connectivity_plus` reports network interfaces, not guaranteed internet access.
Supply `NexioNetworkConfig.connectivityProbe` for a lightweight backend health
check, call `Nexio.checkConnectivity()` on demand, or enable
`verifyBeforeRequest` when every request must be actively checked.

Offline replay is intentionally opt-in twice: enable the runtime capability,
then mark only replay-safe requests:

```dart
await Nexio.post<void>(
  '/analytics/events',
  data: event,
  queueWhenOffline: true,
);
```

Queued requests preserve environment, encryption, authentication mode, content
type, and Chucker policy. Authorization headers are regenerated at replay and
are not persisted by default.

```dart
final snapshot = Nexio.healthSnapshot;
print('Observed outcomes: ${snapshot.total}');
await Nexio.flushHealth();
```

Health aggregation stores endpoint paths and outcomes, not hosts, query
strings, headers, tokens, or payloads.

## Error Handling

```dart
try {
  await Nexio.get<User>('/me');
} on NexioHttpException<User> catch (error) {
  print(error.response.statusCode);
} on NexioOfflineQueuedException catch (error) {
  print('Queued as ${error.queueId}');
} on NexioException catch (error) {
  print(error.message);
}
```

See the [error guide](doc/errors.md) for the full exception model.

## Production Rules

- Use HTTPS in every non-local environment.
- Provision encryption material outside source control and rotate it with the
  backend.
- Keep `defaultLogInChucker: false`; opt in only non-sensitive debug traffic.
- Use idempotency keys and deliberate retry policies for transactions.
- Namespace cache keys by API version, tenant, locale, country, and account when
  those values change response meaning.
- Enable offline replay only when needed, then opt in each replay-safe endpoint
  with `queueWhenOffline: true`.
- Run backend-specific integration tests on Android and iOS.

Review the [production checklist](doc/production-checklist.md) before shipping.

## Examples

- [Pub.dev quick examples](example/example.md)
- [Runnable Android/iOS app](example/lib/main.dart)
- [Complete feature tour](example/all_features.dart)
- [Fintech and telecom blueprint](example/fintech_telecom_runtime.dart)
- [Mobile integration test](example/integration_test/nexio_runtime_test.dart)

## Guides

- [Getting started](doc/getting-started.md)
- [Environments](doc/environments.md)
- [Interceptors and Chucker](doc/interceptors.md)
- [Authentication hooks](doc/authentication.md)
- [Encryption](doc/encryption.md)
- [Security](doc/security.md)
- [Threading and `await`](doc/threading.md)
- [Caching](doc/caching.md)
- [Retries, cancellation, priority, and deduplication](doc/retries-cancellation-priority.md)
- [Uploads](doc/uploads.md)
- [Downloads](doc/downloads.md)
- [Events](doc/events.md)
- [Connectivity and offline queue](doc/offline-queue.md)
- [Health monitoring](doc/health-monitoring.md)
- [Errors](doc/errors.md)
- [Testing](doc/testing.md)
- [Troubleshooting](doc/troubleshooting.md)
- [Fintech and telecom runtime](doc/fintech-telecom.md)
- [Migration from Dio](doc/migration.md)
- [Production checklist](doc/production-checklist.md)
- [Publishing to pub.dev](doc/publishing.md)

## Supported Platforms

Nexio `0.1.0` supports Flutter applications on Android and iOS. Web and desktop
platforms are not part of the V1 compatibility contract.

## Release Status

`0.1.0` is the first public release. The API is documented and tested, but
applications must still validate their backend contracts, encryption envelopes,
authentication decisions, retry safety, cache policy, and offline behavior.

## Contributing and Security

See [CONTRIBUTING.md](CONTRIBUTING.md) for development and pull-request checks.
Report vulnerabilities according to [SECURITY.md](SECURITY.md); never place
tokens, encryption material, personal data, or exploit details in a public
issue.

## License

Nexio is available under the [MIT License](LICENSE).
