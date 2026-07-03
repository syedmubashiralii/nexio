# Events Guide

Nexio exposes centralized runtime events.

```dart
final subscription = Nexio.events.listen((event) {
  switch (event) {
    case NexioRequestStartedEvent():
      print('started');
    case NexioRequestSuccessEvent():
      print('success');
    case NexioRequestFailedEvent():
      print('failed');
    case NexioRequestCancelledEvent():
      print('cancelled');
    case NexioNetworkChangedEvent():
      print('network changed');
    case NexioUnauthorizedEvent():
      print('unauthorized');
  }
});
```

Network streams:

```dart
Nexio.online.listen((_) => print('online'));
Nexio.offline.listen((_) => print('offline'));
Nexio.networkChanges.listen(print);
```

Nexio does not define token formats or a refresh endpoint. Use events,
`onUnauthorized`, or `NexioAuthConfig` to connect app-owned authentication.

Cancel subscriptions with the lifecycle that created them.
