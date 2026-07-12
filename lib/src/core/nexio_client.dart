import 'dart:async';

import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../auth/nexio_auth_config.dart';
import '../cache/cache_store.dart';
import '../cancellation/cancellation_registry.dart';
import '../config/environment.dart';
import '../config/nexio_request_options.dart';
import '../config/nexio_runtime_options.dart';
import '../config/retry_policy.dart';
import '../encryption/encryption_engine.dart';
import '../errors/nexio_exception.dart';
import '../events/nexio_events.dart';
import '../interceptors/conditional_chucker_interceptor.dart';
import '../interceptors/context_interceptor.dart';
import '../interceptors/encryption_interceptor.dart';
import '../interceptors/nexio_interceptor.dart';
import '../loader/nexio_loader.dart';
import '../logging/nexio_logger.dart';
import '../models/nexio_metrics.dart';
import '../models/nexio_response.dart';
import '../monitoring/nexio_health_monitor.dart';
import '../network/network_monitor.dart';
import '../offline/offline_queue.dart';
import '../parser/nexio_parser.dart';
import '../parser/parser_engine.dart';
import '../scheduler/request_scheduler.dart';
import '../thread/thread_engine.dart';
import '../transfers/nexio_download.dart';
import '../transfers/nexio_upload.dart';

part 'nexio_client_auth.dart';
part 'nexio_client_execution.dart';
part 'nexio_client_runtime.dart';

/// Runtime implementation behind the public [Nexio] facade.
class NexioClient {
  /// Creates and starts a Nexio client.
  ///
  /// Parameters:
  /// - [options] are global runtime options from `Nexio.initialize`.
  NexioClient(this.options)
      : eventBus = NexioEventBus(),
        parserRegistry = NexioParserRegistry(),
        logger = NexioLogger(enabled: options.loggerEnabled),
        cacheStore = NexioCacheStore(options.cacheConfig),
        encryptionEngine = NexioEncryptionEngine(options.encryptionConfig),
        healthMonitor = NexioHealthMonitor(options.healthConfig),
        scheduler = NexioRequestScheduler(
          maxConcurrentRequests: options.maxConcurrentRequests,
        ) {
    _environment = options.initialEnvironment;
    _validateEnvironment(_environment);
    if (options.enableChucker) {
      ChuckerFlutter.configure(showNotification: true);
    }

    loaderController =
        NexioLoaderController(navigatorKey: options.navigatorKey);
    cancellationRegistry = NexioCancellationRegistry(eventBus);
    networkMonitor = NexioNetworkMonitor(
      eventBus: eventBus,
      config: options.networkConfig,
    );
    parserEngine = NexioParserEngine(
      registry: parserRegistry,
      threadEngine: NexioThreadEngine(),
    );
    offlineQueue = NexioOfflineQueue(eventBus: eventBus);

    unawaited(_startBackgroundServices());
  }

  /// Global runtime options.
  final NexioRuntimeOptions options;

  /// Dio instance for the currently selected environment.
  Dio get dio => _dioFor(_environment);

  /// Runtime event bus.
  final NexioEventBus eventBus;

  /// Registry for typed model parsers.
  final NexioParserRegistry parserRegistry;

  /// In-memory and console logger.
  final NexioLogger logger;

  /// Cache store.
  final NexioCacheStore cacheStore;

  /// Encryption engine.
  final NexioEncryptionEngine encryptionEngine;

  /// Priority scheduler.
  final NexioRequestScheduler scheduler;

  /// Aggregated network health monitor.
  final NexioHealthMonitor healthMonitor;

  /// Loader controller.
  late final NexioLoaderController loaderController;

  /// Cancellation registry.
  late final NexioCancellationRegistry cancellationRegistry;

  /// Network monitor.
  late final NexioNetworkMonitor networkMonitor;

  /// Response parser engine.
  late final NexioParserEngine parserEngine;

  /// Offline queue.
  late final NexioOfflineQueue offlineQueue;

  final Map<String, Future<Object?>> _inFlight = <String, Future<Object?>>{};
  final Map<String, Dio> _dioPool = <String, Dio>{};
  final Set<Dio> _configuredDio = Set<Dio>.identity();
  Completer<bool>? _authRefreshCompleter;
  bool _authSessionExpired = false;
  int _authGeneration = 0;
  late String _environment;

  /// Active environment.
  String get currentEnvironment => _environment;

  /// Configuration for the active environment.
  NexioEnvironment get currentEnvironmentConfig =>
      _environmentConfig(_environment);

  /// Whether authenticated requests are blocked after session expiry.
  bool get isAuthSessionExpired => _authSessionExpired;

  /// Opens the authenticated request gate after the app establishes a session.
  void resetAuthSession() {
    _authSessionExpired = false;
    _authGeneration += 1;
    if (options.offlineQueueEnabled && networkMonitor.isOnline) {
      unawaited(offlineQueue.replay(_replayQueuedRequest));
    }
  }

  /// Switches the active environment without reinitializing Dio.
  ///
  /// Parameters:
  /// - [environment] is the environment future requests should use.
  void switchEnvironment(String environment) {
    _validateEnvironment(environment);
    _environment = environment;
  }

  /// Resolves [path] against the active environment or [baseUrlOverride].
  ///
  /// Parameters:
  /// - [path] may be relative or absolute.
  /// - [baseUrlOverride] overrides the active environment for one request.
  String resolveUrl(String path, {String? baseUrlOverride}) {
    return _resolveUrlFor(
      path,
      environmentName: _environment,
      baseUrlOverride: baseUrlOverride,
    );
  }

  String _resolveUrlFor(
    String path, {
    required String environmentName,
    String? baseUrlOverride,
  }) {
    final parsed = Uri.tryParse(path);
    if (parsed != null && parsed.hasScheme) {
      return path;
    }
    final baseUrl =
        baseUrlOverride ?? _environmentConfig(environmentName).baseUrl;
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse(normalizedBase).resolve(normalizedPath).toString();
  }

  /// Registers a model parser for type [T].
  ///
  /// Parameters:
  /// - [parser] converts decoded response data into [T].
  void registerParser<T>(NexioParser<T> parser) {
    parserRegistry.register<T>(parser);
  }

  /// Registers a custom encryption [cipher].
  ///
  /// Parameters:
  /// - [cipher] handles one encryption mode.
  void registerCipher(NexioCipher cipher) {
    encryptionEngine.registerCipher(cipher);
  }

  /// Registers an app-specific encryption wire-format [adapter].
  ///
  /// Parameters:
  /// - [adapter] replaces built-in transformation for its encryption mode.
  void registerEncryptionAdapter(NexioEncryptionAdapter adapter) {
    encryptionEngine.registerAdapter(adapter);
  }

  /// Runs a typed request.
  ///
  /// Parameters:
  /// - [requestOptions] contains per-request configuration and hooks.
  Future<NexioResponse<T>> request<T>(
    NexioRequestOptions<T> requestOptions,
  ) async {
    if (requestOptions.authMode == NexioAuthMode.authenticated &&
        _authSessionExpired) {
      throw const NexioSessionExpiredException();
    }
    final environmentName = _environment;
    final url = _resolveUrlFor(
      requestOptions.path,
      environmentName: environmentName,
      baseUrlOverride: requestOptions.baseUrlOverride,
    );
    final cacheKey = NexioCacheStore.buildKey(
      method: requestOptions.method,
      url: url,
      queryParameters: requestOptions.queryParameters,
      data: requestOptions.data,
      extra: requestOptions.cacheKeyExtra,
    );

    final deduplicationKey = _deduplicationKey<T>(
      cacheKey,
      requestOptions,
      environmentName,
    );

    if (requestOptions.deduplicate) {
      final existing = _inFlight[deduplicationKey];
      if (existing != null) {
        return existing.then((response) => response as NexioResponse<T>);
      }
    }

    final future = scheduler.schedule<NexioResponse<T>>(
      requestOptions.priority,
      () => _requestWithLifecycle<T>(
        requestOptions,
        url,
        cacheKey,
        environmentName,
      ),
    );

    if (requestOptions.deduplicate) {
      _inFlight[deduplicationKey] = future;
    }

    try {
      return await future;
    } finally {
      if (requestOptions.deduplicate) {
        _inFlight.remove(deduplicationKey);
      }
    }
  }

  String _deduplicationKey<T>(
    String cacheKey,
    NexioRequestOptions<T> requestOptions,
    String environmentName,
  ) {
    final dioOptions = requestOptions.dioOptions;
    return NexioCacheStore.buildKey(
      method: 'NEXIO_DEDUPLICATION',
      url: cacheKey,
      extra: <String, Object?>{
        'environment': environmentName,
        'type': T.toString(),
        'parser': requestOptions.parser == null
            ? null
            : identityHashCode(requestOptions.parser),
        'isolateParser': requestOptions.isolateParser == null
            ? null
            : identityHashCode(requestOptions.isolateParser),
        'headers': <String, Object?>{
          ...?requestOptions.headers,
          ...?dioOptions?.headers,
        },
        'contentType': requestOptions.contentType ?? dioOptions?.contentType,
        'responseType': dioOptions?.responseType?.name,
        'encryptionMode':
            (requestOptions.encryptionMode ?? options.defaultEncryptionMode)
                .name,
        'authMode': requestOptions.authMode.name,
        'authGeneration': _authGeneration,
      },
    );
  }

  /// Creates an upload request with multipart files.
  ///
  /// Parameters:
  /// - [path] is a relative path or absolute URL.
  /// - [files] are multipart file descriptors.
  /// - [fields] are extra multipart fields.
  /// - [optionsBuilder] customizes the generated request options.
  Future<NexioResponse<T>> upload<T>(
    String path, {
    required List<NexioUploadFile> files,
    Map<String, Object?> fields = const <String, Object?>{},
    NexioRequestOptions<T> Function(FormData formData)? optionsBuilder,
  }) async {
    final formData = FormData();
    formData.fields.addAll(
      fields.entries.map((entry) => MapEntry(entry.key, '${entry.value}')),
    );
    for (final file in files) {
      formData.files.add(await file.toMultipartEntry());
    }
    final requestOptions = optionsBuilder?.call(formData) ??
        NexioRequestOptions<T>(
          method: 'POST',
          path: path,
          data: formData,
          contentType: Headers.multipartFormDataContentType,
        );
    return request<T>(requestOptions);
  }

  /// Creates a download task.
  ///
  /// Parameters:
  /// - [path] is a relative path or absolute URL.
  /// - [destinationPath] is the local file destination.
  /// - [queryParameters] are appended to the URL.
  /// - [headers] override or add request headers.
  /// - [baseUrlOverride] replaces the active environment base URL.
  /// - [onProgress] receives download progress.
  /// - [autoStart] starts the task immediately. Defaults to `true`.
  /// - [logInChucker] overrides Chucker capture for this download.
  /// - [authMode] controls dynamic auth headers for this download.
  NexioDownloadTask download(
    String path, {
    required String destinationPath,
    Map<String, Object?>? queryParameters,
    Map<String, Object?>? headers,
    String? baseUrlOverride,
    ProgressCallback? onProgress,
    bool autoStart = true,
    bool? logInChucker,
    NexioAuthMode authMode = NexioAuthMode.authenticated,
  }) {
    if (authMode == NexioAuthMode.authenticated && _authSessionExpired) {
      throw const NexioSessionExpiredException();
    }
    final url = resolveUrl(path, baseUrlOverride: baseUrlOverride);
    return NexioDownloadTask(
      dio: dio,
      url: url,
      destinationPath: destinationPath,
      queryParameters: queryParameters,
      options: Options(
        headers: headers,
        extra: <String, Object?>{
          NexioRequestMetadata.environmentName: _environment,
          NexioRequestMetadata.logInChucker:
              logInChucker ?? options.defaultLogInChucker,
          NexioRequestMetadata.encryptionMode: EncryptionMode.none,
          NexioRequestMetadata.authMode: authMode,
        },
      ),
      onProgress: onProgress,
      autoStart: autoStart,
    );
  }

  /// Opens Chucker logs when enabled, otherwise shows Nexio's local log list.
  ///
  /// Parameters:
  /// - [context] is used when showing Nexio's fallback log sheet.
  void showLogs(BuildContext context) {
    if (options.enableChucker) {
      ChuckerFlutter.showChuckerScreen();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final entries = logger.entries.reversed.toList();
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, index) {
            final entry = entries[index];
            return ListTile(
              dense: true,
              title: Text(entry.message),
              subtitle: Text(entry.timestamp.toIso8601String()),
            );
          },
        );
      },
    );
  }
}

class _NetworkResult<T> {
  const _NetworkResult({
    required this.response,
    required this.rawData,
  });

  final NexioResponse<T> response;
  final Object? rawData;
}

class _RetryableStatusException implements Exception {
  const _RetryableStatusException(this.response);

  final Response<Object?> response;
}

bool _expectsBytes<T>() => <T>[] is List<List<int>>;
