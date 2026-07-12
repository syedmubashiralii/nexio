part of 'nexio_client.dart';

extension on NexioClient {
  bool _shouldRetry(Object error, RetryPolicy policy, int attempt) {
    if (attempt >= policy.retries) {
      return false;
    }
    if (error is _RetryableStatusException) {
      return policy.shouldRetryStatus(error.response.statusCode);
    }
    return policy.shouldRetryException(error);
  }

  bool _canQueueOffline<T>(NexioRequestOptions<T> requestOptions) {
    return options.offlineQueueEnabled && requestOptions.queueWhenOffline;
  }

  bool _shouldQueueOffline<T>(
    Object error,
    NexioRequestOptions<T> requestOptions,
  ) {
    return _canQueueOffline(requestOptions) &&
        error is DioException &&
        error.type == DioExceptionType.connectionError;
  }

  NexioHealthOutcome _healthOutcomeFor(DioException error) {
    if (CancelToken.isCancel(error)) {
      return NexioHealthOutcome.cancelled;
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        NexioHealthOutcome.timeout,
      DioExceptionType.connectionError => NexioHealthOutcome.offline,
      _ => error.response?.statusCode == 401
          ? NexioHealthOutcome.unauthorized
          : NexioHealthOutcome.serverError,
    };
  }

  Future<String> _queueOffline<T>(
    NexioRequestOptions<T> requestOptions,
    String url,
    String environmentName,
  ) {
    final allowedHeaders = options.offlinePersistedHeaders
        .map((header) => header.toLowerCase())
        .toSet();
    final requestHeaders = <String, Object?>{
      ...?requestOptions.headers,
      ...?requestOptions.dioOptions?.headers,
    };
    return offlineQueue.enqueue(
      method: requestOptions.method,
      url: url,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      headers: <String, Object?>{
        for (final entry in requestHeaders.entries)
          if (allowedHeaders.contains(entry.key.toLowerCase()))
            entry.key: entry.value,
      },
      environmentName: environmentName,
      encryptionMode:
          requestOptions.encryptionMode ?? options.defaultEncryptionMode,
      authMode: requestOptions.authMode,
      contentType:
          requestOptions.contentType ?? requestOptions.dioOptions?.contentType,
      logInChucker: requestOptions.logInChucker ?? options.defaultLogInChucker,
    );
  }

  Future<void> _startBackgroundServices() async {
    await cacheStore.cleanupExpired().catchError((Object _) {});
    await networkMonitor.start().catchError((Object _) {});
    if (options.offlineQueueEnabled && networkMonitor.isOnline) {
      unawaited(offlineQueue.replay(_replayQueuedRequest));
    }
    networkMonitor.online.listen((_) {
      if (options.offlineQueueEnabled) {
        unawaited(offlineQueue.replay(_replayQueuedRequest));
      }
    });
  }

  Future<Response<Object?>> _replayQueuedRequest(
    NexioQueuedRequest request,
  ) {
    if (request.authMode == NexioAuthMode.authenticated &&
        _authSessionExpired) {
      throw const NexioSessionExpiredException();
    }
    final environmentName = request.environmentName ?? _environment;
    return _dioFor(environmentName).request<Object?>(
      request.url,
      data: request.data,
      queryParameters: request.queryParameters,
      options: Options(
        method: request.method,
        headers: request.headers,
        contentType: request.contentType,
        extra: <String, Object?>{
          NexioRequestMetadata.environmentName: environmentName,
          NexioRequestMetadata.encryptionMode: request.encryptionMode,
          NexioRequestMetadata.authMode: request.authMode,
          NexioRequestMetadata.logInChucker: request.logInChucker,
        },
      ),
    );
  }

  Dio _dioFor(String environmentName) {
    final cached = _dioPool[environmentName];
    if (cached != null) {
      return cached;
    }

    final environment = _environmentConfig(environmentName);
    final client = options.dioFactory?.call(environmentName, environment) ??
        (options.dio != null && _dioPool.isEmpty ? options.dio! : Dio());
    client.options.baseUrl = environment.baseUrl;
    client.options.connectTimeout = environment.connectTimeout;
    client.options.sendTimeout = environment.sendTimeout;
    client.options.receiveTimeout = environment.receiveTimeout;
    _configureDio(client);
    _dioPool[environmentName] = client;
    return client;
  }

  void _configureDio(Dio client) {
    if (!_configuredDio.add(client)) {
      return;
    }
    client.interceptors.add(
      NexioContextInterceptor(
        defaultHeaders: options.defaultHeaders,
        environmentProvider: (name) => _environmentConfig(name ?? _environment),
        dynamicHeadersProvider: options.authConfig?.headersProvider,
      ),
    );
    for (final factory in options.interceptorFactories) {
      client.interceptors.add(factory());
    }
    client.interceptors.add(NexioEncryptionInterceptor(encryptionEngine));
    client.interceptors.add(logger);
    if (options.enableChucker) {
      client.interceptors.add(NexioConditionalChuckerInterceptor());
    }
  }

  void _validateEnvironment(String environment) {
    final config = options.environments[environment];
    if (config == null || config.baseUrl.isEmpty) {
      throw NexioEnvironmentException(
        'No base URL configured for "$environment".',
      );
    }
    final uri = Uri.tryParse(config.baseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw NexioEnvironmentException(
        'Environment "$environment" must use an absolute base URL.',
      );
    }
  }

  NexioEnvironment _environmentConfig(String environment) {
    _validateEnvironment(environment);
    return options.environments[environment]!;
  }
}
