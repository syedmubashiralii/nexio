part of 'nexio_client.dart';

extension on NexioClient {
  Future<void> _waitForAuthRefreshIfNeeded() async {
    final authConfig = options.authConfig;
    final refreshCompleter = _authRefreshCompleter;
    if (authConfig == null ||
        !authConfig.queueWhileRefreshing ||
        refreshCompleter == null) {
      return;
    }
    await refreshCompleter.future;
  }

  Future<_NetworkResult<T>?> _handleAuthDecisionIfNeeded<T>({
    required NexioRequestOptions<T> requestOptions,
    required String url,
    required RetryPolicy retryPolicy,
    required int retryAttempt,
    required int authRefreshAttempt,
    required String environmentName,
    required Response<Object?> response,
    required Object? data,
  }) async {
    final authConfig = options.authConfig;
    if (authConfig == null) {
      if (response.statusCode == 401) {
        final event =
            NexioUnauthorizedEvent(url: url, environment: environmentName);
        eventBus.emit(event);
        options.onUnauthorized?.call(event);
      }
      return null;
    }

    final signal = NexioAuthSignal(
      statusCode: response.statusCode,
      data: data,
      url: url,
      environment: environmentName,
      requestOptions: response.requestOptions,
      refreshAttempt: authRefreshAttempt,
    );
    final decision = authConfig.decisionFor(signal);

    if (decision == NexioAuthDecision.proceed) {
      return null;
    }

    if (decision == NexioAuthDecision.expireSession) {
      healthMonitor.record(url, NexioHealthOutcome.unauthorized);
      _emitUnauthorized(url, environmentName);
      authConfig.onSessionExpired?.call(signal);
      throw NexioException('Nexio auth session expired.');
    }

    _emitUnauthorized(url, environmentName);
    healthMonitor.record(url, NexioHealthOutcome.authRefresh);
    if (authRefreshAttempt >= authConfig.maxRefreshAttempts ||
        authConfig.refresh == null) {
      authConfig.onSessionExpired?.call(signal);
      throw NexioException('Nexio auth refresh failed or was not configured.');
    }

    final refreshed = await _refreshAuth(signal, authConfig);
    if (!refreshed) {
      authConfig.onSessionExpired?.call(signal);
      throw NexioException('Nexio auth refresh returned false.');
    }

    return _networkOnce<T>(
      requestOptions,
      url,
      environmentName,
      retryPolicy,
      retryAttempt,
      authRefreshAttempt: authRefreshAttempt + 1,
    );
  }

  Future<bool> _refreshAuth(
    NexioAuthSignal signal,
    NexioAuthConfig authConfig,
  ) async {
    final existing = _authRefreshCompleter;
    if (existing != null) {
      return existing.future;
    }

    final completer = Completer<bool>();
    _authRefreshCompleter = completer;
    try {
      final refreshed = await Future.value(authConfig.refresh!(signal));
      completer.complete(refreshed);
      return refreshed;
    } catch (error, stackTrace) {
      completer.complete(false);
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      _authRefreshCompleter = null;
    }
  }

  void _emitUnauthorized(String url, String environmentName) {
    final event =
        NexioUnauthorizedEvent(url: url, environment: environmentName);
    eventBus.emit(event);
    options.onUnauthorized?.call(event);
  }
}
