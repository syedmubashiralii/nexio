# Health Monitoring Guide

Nexio aggregates low-cardinality outcomes by endpoint path:

- `ok`
- `offline`
- `timeout`
- `cancelled`
- `authRefresh`
- `unauthorized`
- `serverError`

```dart
Nexio.initialize(
  environments: environments,
  initialEnvironment: 'production',
  healthConfig: NexioHealthConfig(
    flushEveryRequests: 25,
    flushInterval: const Duration(minutes: 15),
    onFlush: (snapshot) async {
      await analytics.sendNetworkHealth(snapshot);
    },
  ),
);
```

Read or flush manually:

```dart
final current = Nexio.healthSnapshot;
print(current.total);

Nexio.healthSnapshots.listen(uploadSnapshot);
await Nexio.flushHealth();
```

URLs are reduced to paths. Query strings, hosts, payloads, headers, and tokens
are not stored in health snapshots.

Keep endpoint paths low-cardinality. Avoid embedding account IDs, phone
numbers, or other identifiers into path segments when those paths feed
telemetry.
