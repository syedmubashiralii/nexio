# Fintech and Telecom Runtime Guide

Large fintech, wallet, telecom, and self-care apps usually hit the same network
bottlenecks:

- many feature controllers manually copy device, locale, channel, token, and
  MSISDN metadata into every request;
- foreground loaders appear late because slow GPS, permission, or cache work
  happens before the API layer starts;
- access-token or gateway-token refresh creates duplicate refresh calls;
- requests continue after a session has already expired;
- dashboard and catalog APIs need cache invalidation by remote-config API
  version, country, language, and account;
- large offer/catalog responses should not be decoded on the UI isolate;
- transactional calls need idempotency and double-submit protection.

Nexio solves these as a runtime, not as another generated API class.

## Dynamic Enterprise Headers

Use `authConfig.headersProvider` for data that can change at runtime:

```dart
authConfig: NexioAuthConfig(
  headersProvider: () => {
    'Authorization': 'Bearer ${session.accessToken}',
    'X-Gateway-Token': session.gatewayToken,
    'X-Device-Id': device.deviceId,
    'X-App-Version': device.appVersion,
    'X-Language': device.languageCode,
    'X-Country': device.countryCode,
  },
)
```

Enable Chucker capability once and opt in per safe request:

```dart
await Nexio.get('/offers', logInChucker: true);
await Nexio.post('/payments', data: payment, logInChucker: false);
```

Nexio evaluates these headers before each request and again after refresh before
retrying.

## Token and Gateway Refresh Without Backend Lock-In

Nexio does not know your auth backend. Instead, it coordinates your callback:

```dart
authConfig: NexioAuthConfig(
  decide: (signal) {
    if (signal.statusCode == 401) {
      return NexioAuthDecision.refreshAndRetry;
    }
    final data = signal.data;
    if (data is Map && data['responseCode'] == '410') {
      return NexioAuthDecision.refreshAndRetry;
    }
    if (data is Map && data['responseCode'] == '411') {
      return NexioAuthDecision.expireSession;
    }
    return NexioAuthDecision.proceed;
  },
  refresh: (_) async {
    final success = await refreshAccessAndGatewayTokens();
    return success;
  },
  onSessionExpired: (_) => redirectToLoginOnce(),
)
```

Only one refresh callback runs at a time. Other protected requests wait and then
retry with fresh headers.

## Versioned Cache for Remote Config APIs

Use `cacheKeyExtra` when an API response depends on remote-config versions,
country, language, tenant, or account:

```dart
await Nexio.get<List<Offer>>(
  '/dashboard/offers',
  cachePolicy: CachePolicy.cacheFirst,
  cacheKeyExtra: {
    'apiVersion': remoteConfig.dashboardOffersVersion,
    'country': countryCode,
    'language': languageCode,
    'msisdn': currentMsisdn,
  },
);
```

When the version changes, Nexio reads a different cache entry automatically.

## Loader Timing

For screen flows that do permission or GPS work before requesting data, make the
page own the visible loader immediately and call Nexio with `showLoader: false`.
Use Nexio's loader for pure foreground API actions where the request starts
immediately.

```dart
isLoading.value = true;
final location = await resolveLocation();
final stores = await Nexio.get<Map<String, Object?>>(
  '/stores',
  queryParameters: {'lat': location.lat, 'lng': location.lng},
  showLoader: false,
);
isLoading.value = false;
```

## Threading

Do not move all network I/O into isolates. Dio requests are asynchronous I/O and
do not block Flutter frames while awaited. Use isolates for CPU work:

```dart
await Nexio.get<List<Offer>>(
  '/large-catalog',
  threadMode: ThreadMode.auto,
  parseThresholdKb: 32,
);
```

Small payloads parse on the main isolate. Large built-in JSON decoding moves to
a background isolate.

## Transaction Safety

For payments and wallet operations, use idempotency keys, high priority, no
automatic retry unless the backend contract allows it, and no duplicate sharing
unless identical transaction calls should receive the same response:

```dart
await Nexio.post<PaymentReceipt>(
  '/payments/merchant',
  data: paymentBody,
  headers: {'X-Idempotency-Key': idempotencyKey},
  encryptionMode: EncryptionMode.aesGcm,
  retryPolicy: const RetryPolicy(retries: 0),
  priority: RequestPriority.high,
  deduplicate: false,
);
```

See `example/fintech_telecom_runtime.dart` for a complete blueprint.
