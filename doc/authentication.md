# Authentication Hooks

Nexio coordinates authentication failures without defining an authentication
protocol. Your application owns token storage, refresh endpoints, request
bodies, response parsing, session expiry, and navigation.

## Dynamic Headers

`headersProvider` runs before every request and again when a request is retried
after refresh. It may return a map immediately or return a `Future`.

```dart
Nexio.initialize(
  environments: environments,
  initialEnvironment: 'production',
  authConfig: NexioAuthConfig(
    headersProvider: () async {
      final session = await sessionStore.read();
      return {
        if (session.accessToken != null)
          'Authorization': 'Bearer ${session.accessToken}',
        if (session.gatewayToken != null)
          'X-Gateway-Token': session.gatewayToken,
        'X-Device-Id': deviceContext.deviceId,
        'X-App-Version': deviceContext.appVersion,
      };
    },
  ),
);
```

Header precedence is:

```text
global headers -> environment headers -> dynamic headers -> request headers
```

Later values replace earlier values with the same key.

## Anonymous Requests and Session Gate

Sign-in, registration, public configuration, and refresh endpoints should not
receive stale auth headers or participate in refresh classification:

```dart
final response = await Nexio.post<Session>(
  '/auth/sign-in',
  authMode: NexioAuthMode.anonymous,
  data: credentials,
  parser: Session.parse,
);

await sessionStore.save(response.data);
Nexio.resetAuthSession();
```

When `decide` returns `expireSession`, or refresh fails, Nexio blocks future
authenticated requests with `NexioSessionExpiredException`. Anonymous requests
continue so the app can recover. Call `Nexio.resetAuthSession()` only after the
app has established a valid replacement session.

## Classify Authentication Responses

By default, Nexio requests a refresh for HTTP 401 only when a `refresh`
callback is configured. Use `decide` when a backend reports token or gateway
state in a response body.

```dart
NexioAuthDecision decideAuth(NexioAuthSignal signal) {
  if (signal.statusCode == 401) {
    return NexioAuthDecision.refreshAndRetry;
  }

  final data = signal.data;
  if (data is Map) {
    final responseCode = data['responseCode']?.toString();
    if (responseCode == '410') {
      return NexioAuthDecision.refreshAndRetry;
    }
    if (responseCode == '411' || responseCode == '423') {
      return NexioAuthDecision.expireSession;
    }
  }

  return NexioAuthDecision.proceed;
}
```

`NexioAuthSignal` contains the status, available response data, resolved URL,
environment name, Dio request options, and current refresh-attempt count.

## App-Owned Refresh

The callback returns `true` only after new session values have been stored and
future calls to `headersProvider` can read them.

```dart
authConfig: NexioAuthConfig(
  headersProvider: sessionStore.headers,
  decide: decideAuth,
  refresh: (signal) async {
    final refreshed = await authApi.refresh(
      refreshToken: sessionStore.refreshToken,
      environment: signal.environment,
    );
    if (refreshed == null) {
      return false;
    }

    await sessionStore.save(refreshed);
    return true;
  },
  onSessionExpired: (_) {
    sessionStore.clear();
    sessionCoordinator.openSignInOnce();
  },
  maxRefreshAttempts: 1,
  queueWhileRefreshing: true,
),
```

Nexio uses a single-flight refresh coordinator. If several protected requests
fail together, one callback runs and waiting requests continue after it
completes. `maxRefreshAttempts` limits refresh retries for one request;
`queueWhileRefreshing` controls whether new protected requests wait for a
refresh already in progress.

## Keep Refresh Transport Independent

Use an app-owned refresh client or dedicated Dio inside the refresh callback.
This avoids recursive classification and avoids scheduling a refresh request
behind protected requests that are already waiting for refresh.

```dart
refresh: (signal) => refreshClient.refresh(
  environment: signal.environment,
  refreshToken: sessionStore.refreshToken,
),
```

If application architecture requires Nexio for refresh, mark that call
`authMode: NexioAuthMode.anonymous`, disable deduplication, and test refresh
under maximum request concurrency. A dedicated refresh transport remains the
recommended production design.

## Unauthorized Events

Use `onUnauthorized` or the global event stream for analytics and session UI.
Make navigation idempotent because several requests can report the same expired
session.

```dart
onUnauthorized: (event) {
  sessionCoordinator.openSignInOnce();
},
```

Nexio never chooses a route, deletes secure storage, or assumes a token schema.

## Authentication Checklist

- Keep access and refresh tokens in platform-backed secure storage.
- Never persist authorization headers through the offline queue unless the app
  accepts that storage model.
- Exclude refresh and sign-in requests from recursive refresh classification.
- Store refreshed tokens before returning `true`.
- Keep session-expiry navigation single-flight.
- Mark public/auth bootstrap requests as `NexioAuthMode.anonymous`.
- Call `Nexio.resetAuthSession()` only after successful authentication.
- Test simultaneous 401 responses, refresh failure, malformed responses, and
  logout while requests are in flight.
