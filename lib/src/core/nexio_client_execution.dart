part of 'nexio_client.dart';

extension on NexioClient {
  Future<NexioResponse<T>> _requestWithLifecycle<T>(
    NexioRequestOptions<T> requestOptions,
    String url,
    String cacheKey,
    String environmentName,
  ) async {
    if (requestOptions.showLoader) {
      loaderController.show(
        context: requestOptions.context,
        loaderWidget: requestOptions.loaderWidget,
        dismissible: requestOptions.dismissible,
        barrierColor: requestOptions.barrierColor,
      );
    }

    try {
      return await _requestWithCache<T>(
        requestOptions,
        url,
        cacheKey,
        environmentName,
      );
    } catch (error, stackTrace) {
      eventBus.emit(NexioRequestFailedEvent(error, stackTrace));
      rethrow;
    } finally {
      if (requestOptions.showLoader) {
        loaderController.hide();
      }
    }
  }

  Future<NexioResponse<T>> _requestWithCache<T>(
    NexioRequestOptions<T> requestOptions,
    String url,
    String cacheKey,
    String environmentName,
  ) async {
    if (requestOptions.cachePolicy == CachePolicy.cacheOnly ||
        requestOptions.cachePolicy == CachePolicy.cacheFirst) {
      final cached = await cacheStore.get(cacheKey);
      if (cached != null) {
        return _fromCache<T>(cached, requestOptions);
      }
      if (requestOptions.cachePolicy == CachePolicy.cacheOnly) {
        throw NexioCacheMissException(cacheKey);
      }
    }

    try {
      final network = await _requestWithRetry<T>(
        requestOptions,
        url,
        environmentName,
      );
      if (requestOptions.cachePolicy != CachePolicy.networkOnly) {
        await cacheStore.put(
          cacheKey,
          NexioCacheEntry(
            data: network.rawData,
            statusCode: network.response.statusCode,
            statusMessage: network.response.statusMessage,
            headers: network.response.headers,
            createdAt: DateTime.now(),
            expiresAt: DateTime.now().add(
              requestOptions.cacheTtl ?? options.cacheConfig.defaultTtl,
            ),
          ),
        );
      }
      return network.response;
    } catch (error) {
      if (requestOptions.cachePolicy == CachePolicy.networkFirst) {
        final cached = await cacheStore.get(cacheKey);
        if (cached != null) {
          return _fromCache<T>(cached, requestOptions);
        }
      }
      rethrow;
    }
  }

  Future<NexioResponse<T>> _fromCache<T>(
    NexioCacheEntry entry,
    NexioRequestOptions<T> requestOptions,
  ) async {
    final parseWatch = Stopwatch()..start();
    final parsed = await parserEngine.parse<T>(
      entry.data,
      parser: requestOptions.parser,
      isolateParser: requestOptions.isolateParser,
      threadMode: requestOptions.threadMode ?? options.defaultThreadMode,
      thresholdKb: requestOptions.parseThresholdKb ?? options.parseThresholdKb,
    );
    parseWatch.stop();
    return NexioResponse<T>(
      data: parsed,
      statusCode: entry.statusCode,
      statusMessage: entry.statusMessage,
      headers: entry.headers,
      metrics: NexioMetrics(
        networkDuration: Duration.zero,
        decryptDuration: Duration.zero,
        parseDuration: parseWatch.elapsed,
        totalDuration: parseWatch.elapsed,
      ),
      fromCache: true,
    );
  }

  Future<_NetworkResult<T>> _requestWithRetry<T>(
    NexioRequestOptions<T> requestOptions,
    String url,
    String environmentName,
  ) async {
    final verifyConnectivity = requestOptions.verifyConnectivity ??
        options.networkConfig.verifyBeforeRequest;
    final isOnline = verifyConnectivity
        ? await networkMonitor.checkNow()
        : networkMonitor.isOnline;
    if (!isOnline) {
      healthMonitor.record(url, NexioHealthOutcome.offline);
      if (_canQueueOffline(requestOptions)) {
        final queueId = await _queueOffline(
          requestOptions,
          url,
          environmentName,
        );
        throw NexioOfflineQueuedException(queueId);
      }
      throw const NexioOfflineException();
    }

    final retryPolicy = requestOptions.retryPolicy ?? options.retryPolicy;
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 0; attempt <= retryPolicy.retries; attempt += 1) {
      try {
        return await _networkOnce<T>(
          requestOptions,
          url,
          environmentName,
          retryPolicy,
          attempt,
        );
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (!_shouldRetry(error, retryPolicy, attempt)) {
          if (_shouldQueueOffline(error, requestOptions)) {
            final queueId = await _queueOffline(
              requestOptions,
              url,
              environmentName,
            );
            throw NexioOfflineQueuedException(queueId);
          }
          rethrow;
        }
        await Future<void>.delayed(retryPolicy.delayForAttempt(attempt + 1));
      }
    }

    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  Future<_NetworkResult<T>> _networkOnce<T>(
    NexioRequestOptions<T> requestOptions,
    String url,
    String environmentName,
    RetryPolicy retryPolicy,
    int attempt, {
    int authRefreshAttempt = 0,
  }) async {
    if (requestOptions.authMode == NexioAuthMode.authenticated &&
        _authSessionExpired) {
      throw const NexioSessionExpiredException();
    }
    await _waitForAuthRefreshIfNeeded(requestOptions.authMode);

    final totalWatch = Stopwatch()..start();
    final cancelToken = requestOptions.cancelToken ?? CancelToken();
    cancellationRegistry.register(
      cancelToken,
      tag: requestOptions.cancelTag,
      group: requestOptions.cancelGroup,
    );

    try {
      eventBus.emit(
        NexioRequestStartedEvent(
          method: requestOptions.method,
          url: url,
          tag: requestOptions.cancelTag,
          group: requestOptions.cancelGroup,
        ),
      );

      final networkWatch = Stopwatch()..start();
      final response = await _dioFor(environmentName).request<Object?>(
        url,
        data: requestOptions.data,
        queryParameters: requestOptions.queryParameters,
        cancelToken: cancelToken,
        onSendProgress: requestOptions.onSendProgress,
        onReceiveProgress: requestOptions.onReceiveProgress,
        options: _dioOptionsFor<T>(requestOptions, environmentName),
      );
      networkWatch.stop();

      if (retryPolicy.shouldRetryStatus(response.statusCode) &&
          attempt < retryPolicy.retries) {
        throw _RetryableStatusException(response);
      }

      final authAction = await _handleAuthDecisionIfNeeded<T>(
        requestOptions: requestOptions,
        url: url,
        retryPolicy: retryPolicy,
        retryAttempt: attempt,
        authRefreshAttempt: authRefreshAttempt,
        environmentName: environmentName,
        response: response,
        data: response.data,
      );
      if (authAction != null) {
        return authAction;
      }

      final decrypted = response.data;
      final decryptDuration = Duration(
        microseconds: response.requestOptions
                .extra[NexioRequestMetadata.decryptDurationMicros] as int? ??
            0,
      );

      final parseWatch = Stopwatch()..start();
      final parsed = await parserEngine.parse<T>(
        decrypted,
        parser: requestOptions.parser,
        isolateParser: requestOptions.isolateParser,
        threadMode: requestOptions.threadMode ?? options.defaultThreadMode,
        thresholdKb:
            requestOptions.parseThresholdKb ?? options.parseThresholdKb,
      );
      parseWatch.stop();
      totalWatch.stop();

      final nexioResponse = NexioResponse<T>(
        data: parsed,
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        headers: response.headers.map,
        metrics: NexioMetrics(
          networkDuration: networkWatch.elapsed,
          decryptDuration: decryptDuration,
          parseDuration: parseWatch.elapsed,
          totalDuration: totalWatch.elapsed,
        ),
        fromCache: false,
        requestOptions: response.requestOptions,
      );

      if ((response.statusCode ?? 0) >= 400) {
        healthMonitor.record(url, NexioHealthOutcome.serverError);
        throw NexioHttpException<T>(nexioResponse);
      }

      healthMonitor.record(url, NexioHealthOutcome.ok);
      eventBus.emit(NexioRequestSuccessEvent<T>(nexioResponse));
      return _NetworkResult<T>(response: nexioResponse, rawData: decrypted);
    } on DioException catch (error) {
      healthMonitor.record(url, _healthOutcomeFor(error));
      if (CancelToken.isCancel(error)) {
        eventBus.emit(
          NexioRequestCancelledEvent(error.message ?? 'Request cancelled.'),
        );
      }
      rethrow;
    } finally {
      cancellationRegistry.unregister(
        cancelToken,
        tag: requestOptions.cancelTag,
        group: requestOptions.cancelGroup,
      );
    }
  }

  Options _dioOptionsFor<T>(
    NexioRequestOptions<T> requestOptions,
    String environmentName,
  ) {
    final existing = requestOptions.dioOptions ?? Options();
    final headers = <String, Object?>{
      ...?requestOptions.headers,
      ...?existing.headers,
    };
    final extra = <String, Object?>{
      ...?existing.extra,
      NexioRequestMetadata.encryptionMode:
          requestOptions.encryptionMode ?? options.defaultEncryptionMode,
      NexioRequestMetadata.logInChucker:
          requestOptions.logInChucker ?? options.defaultLogInChucker,
      NexioRequestMetadata.environmentName: environmentName,
      NexioRequestMetadata.authMode: requestOptions.authMode,
    };
    return existing.copyWith(
      method: requestOptions.method,
      headers: headers,
      extra: extra,
      contentType: requestOptions.contentType ?? existing.contentType,
      responseType: existing.responseType ??
          (_expectsBytes<T>() ? ResponseType.bytes : ResponseType.plain),
      validateStatus: existing.validateStatus ?? (_) => true,
    );
  }
}
