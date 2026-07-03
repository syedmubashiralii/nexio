# Environment Guide

Nexio does not impose a fixed environment enum. Use any names and any number of
environments required by the app.

```dart
Nexio.initialize(
  environments: const {
    'local': NexioEnvironment(
      baseUrl: 'http://10.0.2.2:8080',
      connectTimeout: Duration(seconds: 5),
    ),
    'qa-east': NexioEnvironment(
      baseUrl: 'https://qa-east.example.com',
      headers: {'X-Region': 'east'},
    ),
    'qa-west': NexioEnvironment(
      baseUrl: 'https://qa-west.example.com',
      headers: {'X-Region': 'west'},
    ),
    'uat': NexioEnvironment(baseUrl: 'https://uat.example.com'),
    'production': NexioEnvironment(baseUrl: 'https://api.example.com'),
  },
  initialEnvironment: 'qa-east',
);
```

Switch without reinitialization:

```dart
Nexio.switchEnvironment('production');
print(Nexio.currentEnvironment);
print(Nexio.currentEnvironmentConfig.baseUrl);
```

Nexio creates and caches a configured Dio client the first time an environment
is used. Switching back reuses that client and its socket pool.

Override the base URL for one request:

```dart
await Nexio.get<Map<String, Object?>>(
  '/users',
  baseUrlOverride: 'https://special-domain.com',
);
```

For certificate pinning, proxies, or custom adapters, provide a factory:

```dart
Nexio.initialize(
  environments: environments,
  initialEnvironment: 'uat',
  dioFactory: (name, environment) {
    final dio = Dio();
    dio.httpClientAdapter = buildPinnedAdapter(name, environment);
    return dio;
  },
);
```
