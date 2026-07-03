# Interceptor and Chucker Guide

Nexio uses Dio interceptors as the request/response pipeline.

Built-in interceptors handle:

- global, environment, dynamic, and per-request header precedence;
- CBC/GCM request encryption and response decryption;
- package logging;
- conditional Chucker capture.

## User Interceptors

Use factories because Nexio may create one Dio client per environment:

```dart
Nexio.initialize(
  environments: environments,
  initialEnvironment: 'uat',
  interceptorFactories: [
    () => CorrelationIdInterceptor(),
    () => RequestSignatureInterceptor(),
  ],
);
```

Each factory creates a fresh interceptor for a Dio client. Existing interceptors
on a Dio returned by `dioFactory` are preserved.

## Conditional Chucker

Enable Chucker capability globally, then decide per request:

```dart
Nexio.initialize(
  environments: environments,
  initialEnvironment: 'qa',
  enableChucker: true,
  defaultLogInChucker: false,
);

await Nexio.get('/catalog', logInChucker: true);

await Nexio.post(
  '/payments',
  data: payment,
  logInChucker: false,
);
```

Use `defaultLogInChucker: false` for fintech and telecom apps. Explicitly opt in
only endpoints that are safe to inspect.

## Dynamic Headers

`NexioAuthConfig.headersProvider` runs before every request and again after a
refresh retry:

```dart
authConfig: NexioAuthConfig(
  headersProvider: () => {
    'Authorization': 'Bearer ${session.accessToken}',
    'X-Gateway-Token': session.gatewayToken,
    'X-Device-Id': device.id,
    'X-App-Version': device.appVersion,
  },
)
```

Header precedence is global, environment, dynamic, then per-request.

App-owned interceptors run after context headers and before Nexio encryption.
They can sign or transform plaintext requests, so they must not log sensitive
bodies. Encryption, package logging, and conditional Chucker handling remain
built-in stages.
