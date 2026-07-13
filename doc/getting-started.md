# Getting Started

Add Nexio and fetch dependencies:

```yaml
dependencies:
  nexio: ^0.2.0
```

```bash
flutter pub get
```

Import the package:

```dart
import 'package:nexio/nexio.dart';
```

Initialize Nexio once before the app makes requests:

```dart
Nexio.initialize(
  environments: const {
    'dev': NexioEnvironment(baseUrl: 'https://dev.example.com'),
    'uat': NexioEnvironment(baseUrl: 'https://uat.example.com'),
    'production': NexioEnvironment(baseUrl: 'https://api.example.com'),
  },
  initialEnvironment: 'dev',
  enableChucker: true,
  defaultLogInChucker: false,
  loggerEnabled: true,
);
```

Make a request:

```dart
final response = await Nexio.get<Map<String, Object?>>(
  '/profile',
  logInChucker: true,
  parser: (input) async => Map<String, Object?>.from(input! as Map),
);

print(response.data);
print(response.metrics.networkDuration);
```

Register a parser once when the same model is used often:

```dart
Nexio.registerParser<User>((input) async {
  return User.fromJson(Map<String, Object?>.from(input! as Map));
});

final user = (await Nexio.get<User>('/me')).data;
```

Continue with [environments](environments.md),
[authentication](authentication.md), [security](security.md), and the
[production checklist](production-checklist.md).
