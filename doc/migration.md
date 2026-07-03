# Migration Guide

## From raw Dio

Before:

```dart
final dio = Dio(BaseOptions(baseUrl: 'https://dev.example.com'));
final response = await dio.get('/users');
```

After:

```dart
Nexio.initialize(
  environments: const {
    'dev': NexioEnvironment(baseUrl: 'https://dev.example.com'),
    'qa': NexioEnvironment(baseUrl: 'https://qa.example.com'),
    'uat': NexioEnvironment(baseUrl: 'https://uat.example.com'),
    'production': NexioEnvironment(baseUrl: 'https://api.example.com'),
  },
  initialEnvironment: 'dev',
);

final response = await Nexio.get<List<User>>(
  '/users',
  parser: userListParser,
);
```

## From multiple Dio instances

Replace separate Dio instances with Nexio environments:

```dart
Nexio.switchEnvironment('uat');
```

Use `baseUrlOverride` for one-off domains instead of creating another client.

## From custom response wrappers

Nexio returns `NexioResponse<T>` with typed `data`, headers, status, cache state,
and timing metrics. Move existing model mapping into a parser function or global
parser registration.
