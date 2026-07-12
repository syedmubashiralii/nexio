# Connectivity and Offline Queue

Nexio separates interface connectivity, real backend reachability, and delayed
request replay. Applications choose how much verification each workflow needs.

## Reachability

`connectivity_plus` can report Wi-Fi or mobile service even when the internet or
backend is unavailable. Supply a lightweight app-owned probe when that
distinction matters:

```dart
final probeDio = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 3),
    receiveTimeout: const Duration(seconds: 3),
  ),
);

Nexio.initialize(
  environments: environments,
  initialEnvironment: 'production',
  networkConfig: NexioNetworkConfig(
    connectivityProbe: () async {
      try {
        await probeDio.head('https://api.example.com/health');
        return true;
      } catch (_) {
        return false;
      }
    },
    verifyBeforeRequest: false,
  ),
);
```

Use `verifyBeforeRequest: true` globally only when the extra health request and
latency are acceptable. Override one request with `verifyConnectivity: true`,
or check explicitly:

```dart
final reachable = await Nexio.checkConnectivity();
```

Without a custom probe, `Nexio.isOnline` is best-effort interface state.

## Safe Replay

Offline persistence is disabled by default. Enabling it prepares the runtime;
each replayable endpoint must still opt in:

```dart
Nexio.initialize(
  environments: environments,
  initialEnvironment: 'production',
  offlineQueueEnabled: true,
);

try {
  await Nexio.post<void>(
    '/analytics/events',
    data: event.toJson(),
    queueWhenOffline: true,
    deduplicate: false,
  );
} on NexioOfflineQueuedException catch (error) {
  markPending(error.queueId);
}
```

Do not queue payment, wallet transfer, bundle purchase, password, OTP, or other
non-idempotent operations unless the backend guarantees idempotency and delayed
execution is an explicit product requirement.

## Replay Metadata and Secrets

Queued entries preserve the original absolute URL, environment, request body,
query parameters, encryption mode, auth mode, content type, and Chucker choice.
Replay uses the matching environment's Dio pipeline and evaluates current
dynamic auth headers again.

Authorization and dynamic auth headers are not written to the queue. Only
request headers in `offlinePersistedHeaders` are stored. The secure default is:

```dart
{
  'accept',
  'content-type',
  'x-idempotency-key',
}
```

Customize the allowlist only after reviewing the data classification of each
header. Queue bodies are JSON files in application support storage; do not opt
sensitive payloads into replay unless the app's storage and threat model allow
it.

## Outcomes

- A request that is offline and not opted in throws `NexioOfflineException`.
- An opted-in request that is persisted throws `NexioOfflineQueuedException`.
- An online cold start and connectivity restoration trigger replay automatically.
- Resetting a newly authenticated session retries entries held by the session gate.
- Successful replay emits `NexioRequestSuccessEvent<Object?>`.
- Failed replay remains queued and emits `NexioRequestFailedEvent`.
- Unsupported request values throw `NexioOfflineQueueSerializationException`
  instead of being converted to ambiguous strings.

Treat queued as pending, not successful. Reconcile important mutations with the
backend using an idempotency key and a status endpoint.
