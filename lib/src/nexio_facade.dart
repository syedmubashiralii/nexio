import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import 'auth/nexio_auth_config.dart';
import 'cache/cache_config.dart';
import 'config/encryption_config.dart';
import 'config/environment.dart';
import 'config/nexio_request_options.dart';
import 'config/nexio_runtime_options.dart';
import 'config/retry_policy.dart';
import 'core/nexio_client.dart';
import 'encryption/encryption_engine.dart';
import 'errors/nexio_exception.dart';
import 'events/nexio_events.dart';
import 'interceptors/nexio_interceptor.dart';
import 'models/nexio_response.dart';
import 'monitoring/nexio_health_monitor.dart';
import 'network/network_config.dart';
import 'parser/nexio_parser.dart';
import 'transfers/nexio_download.dart';
import 'transfers/nexio_upload.dart';

/// Static entry point for the Nexio networking runtime.
class Nexio {
  const Nexio._();

  static NexioClient? _client;

  /// Initializes Nexio once from application startup.
  ///
  /// Parameters:
  /// - [environments] maps arbitrary names to environment configurations.
  /// - [initialEnvironment] is the active environment name after initialization.
  /// - [encryptionConfig] provides AES-CBC and AES-GCM secrets.
  /// - [defaultEncryptionMode] is used by requests that do not override
  ///   encryption. Defaults to [EncryptionMode.none].
  /// - [loggerEnabled] enables in-memory and console logging.
  /// - [enableChucker] installs Chucker's Dio interceptor.
  /// - [defaultLogInChucker] is the default capture decision for requests.
  /// - [interceptorFactories] creates app-owned interceptors for each Dio.
  /// - [retryPolicy] is the global retry policy.
  /// - [cacheConfig] controls memory and disk caching.
  /// - [defaultThreadMode] controls response parsing placement.
  /// - [parseThresholdKb] controls [ThreadMode.auto]. Defaults to `64`.
  /// - [offlineQueueEnabled] stores no-connectivity failures for replay.
  ///   Requests opt in individually with `queueWhenOffline`.
  /// - [offlinePersistedHeaders] allows selected non-secret request headers to
  ///   be stored with queued requests.
  /// - [networkConfig] controls real reachability checks.
  /// - [healthConfig] controls aggregated network health monitoring.
  /// - [maxConcurrentRequests] caps scheduler concurrency. Defaults to `6`.
  /// - [defaultHeaders] are added to every request unless overridden.
  /// - [authConfig] supplies dynamic headers and backend-agnostic auth/session
  ///   refresh coordination.
  /// - [navigatorKey] enables global loaders without per-request context.
  /// - [dio] injects a custom Dio instance for tests or advanced transport.
  /// - [dioFactory] creates environment-specific Dio instances.
  /// - [onUnauthorized] receives HTTP 401 events; auth refresh stays app-owned.
  static void initialize({
    required Map<String, NexioEnvironment> environments,
    required String initialEnvironment,
    EncryptionConfig encryptionConfig = const EncryptionConfig(),
    EncryptionMode defaultEncryptionMode = EncryptionMode.none,
    bool loggerEnabled = false,
    bool enableChucker = false,
    bool defaultLogInChucker = false,
    List<NexioInterceptorFactory> interceptorFactories =
        const <NexioInterceptorFactory>[],
    RetryPolicy retryPolicy = RetryPolicy.none,
    CacheConfig cacheConfig = const CacheConfig(),
    ThreadMode defaultThreadMode = ThreadMode.auto,
    int parseThresholdKb = 64,
    bool offlineQueueEnabled = false,
    Set<String> offlinePersistedHeaders = const <String>{
      'accept',
      'content-type',
      'x-idempotency-key',
    },
    NexioNetworkConfig networkConfig = const NexioNetworkConfig(),
    NexioHealthConfig healthConfig = const NexioHealthConfig(),
    int maxConcurrentRequests = 6,
    Map<String, Object?> defaultHeaders = const <String, Object?>{},
    NexioAuthConfig? authConfig,
    GlobalKey<NavigatorState>? navigatorKey,
    Dio? dio,
    Dio Function(String name, NexioEnvironment environment)? dioFactory,
    void Function(NexioUnauthorizedEvent event)? onUnauthorized,
  }) {
    _client = NexioClient(
      NexioRuntimeOptions(
        environments: environments,
        initialEnvironment: initialEnvironment,
        encryptionConfig: encryptionConfig,
        defaultEncryptionMode: defaultEncryptionMode,
        loggerEnabled: loggerEnabled,
        enableChucker: enableChucker,
        defaultLogInChucker: defaultLogInChucker,
        interceptorFactories: interceptorFactories,
        retryPolicy: retryPolicy,
        cacheConfig: cacheConfig,
        defaultThreadMode: defaultThreadMode,
        parseThresholdKb: parseThresholdKb,
        offlineQueueEnabled: offlineQueueEnabled,
        offlinePersistedHeaders: offlinePersistedHeaders,
        networkConfig: networkConfig,
        healthConfig: healthConfig,
        maxConcurrentRequests: maxConcurrentRequests,
        defaultHeaders: defaultHeaders,
        authConfig: authConfig,
        navigatorKey: navigatorKey,
        dio: dio,
        dioFactory: dioFactory,
        onUnauthorized: onUnauthorized,
      ),
    );
  }

  /// Current active environment.
  static String get currentEnvironment => _required.currentEnvironment;

  /// Configuration for the active environment.
  static NexioEnvironment get currentEnvironmentConfig =>
      _required.currentEnvironmentConfig;

  /// Whether the network monitor currently reports an online transport.
  static bool get isOnline => _required.networkMonitor.isOnline;

  /// Whether protected requests are blocked after authentication expiry.
  static bool get isAuthSessionExpired => _required.isAuthSessionExpired;

  /// Performs an immediate interface and optional reachability check.
  static Future<bool> checkConnectivity() =>
      _required.networkMonitor.checkNow();

  /// Opens the protected-request gate after the app establishes a new session.
  static void resetAuthSession() {
    _required.resetAuthSession();
  }

  /// Stream of every Nexio event.
  static Stream<NexioEvent> get events => _required.eventBus.stream;

  /// Stream of network state changes.
  static Stream<bool> get networkChanges => _required.networkMonitor.changes;

  /// Stream that emits when the device appears online.
  static Stream<bool> get online => _required.networkMonitor.online;

  /// Stream that emits when the device appears offline.
  static Stream<bool> get offline => _required.networkMonitor.offline;

  /// Current unflushed network health aggregate.
  static NexioHealthSnapshot get healthSnapshot =>
      _required.healthMonitor.current;

  /// Stream of flushed network health aggregates.
  static Stream<NexioHealthSnapshot> get healthSnapshots =>
      _required.healthMonitor.snapshots;

  /// Flushes the current network health aggregate immediately.
  static Future<void> flushHealth() => _required.healthMonitor.flush();

  /// Switches the active environment without reinitializing Nexio.
  ///
  /// Parameters:
  /// - [environment] is the environment future requests should use.
  static void switchEnvironment(String environment) {
    _required.switchEnvironment(environment);
  }

  /// Resolves a path against the active environment.
  ///
  /// Parameters:
  /// - [path] is a relative path or absolute URL.
  /// - [baseUrlOverride] overrides the active environment for this resolution.
  static String resolveUrl(String path, {String? baseUrlOverride}) {
    return _required.resolveUrl(path, baseUrlOverride: baseUrlOverride);
  }

  /// Registers a typed model parser.
  ///
  /// Parameters:
  /// - [parser] converts decoded response data into [T].
  static void registerParser<T>(NexioParser<T> parser) {
    _required.registerParser<T>(parser);
  }

  /// Registers a custom encryption cipher.
  ///
  /// Parameters:
  /// - [cipher] handles one [EncryptionMode].
  static void registerCipher(NexioCipher cipher) {
    _required.registerCipher(cipher);
  }

  /// Registers an app-specific encryption wire-format adapter.
  ///
  /// Parameters:
  /// - [adapter] replaces built-in transformation for its encryption mode.
  static void registerEncryptionAdapter(NexioEncryptionAdapter adapter) {
    _required.registerEncryptionAdapter(adapter);
  }

  /// Runs a fully configurable request.
  ///
  /// Parameters:
  /// - [method] is the HTTP method.
  /// - [path] is a relative path or absolute URL.
  /// - [data] is the request body.
  /// - [queryParameters] are appended to the URL.
  /// - [headers] override or add request headers.
  /// - [baseUrlOverride] replaces the active environment base URL.
  /// - [encryptionMode] overrides global encryption for this request.
  /// - [authMode] controls dynamic auth headers and session coordination.
  /// - [threadMode] overrides global parsing placement.
  /// - [retryPolicy] overrides global retry behavior.
  /// - [cachePolicy] controls cache reads and writes.
  /// - [cacheTtl] controls response cache lifetime.
  /// - [cacheKeyExtra] namespaces cache entries by metadata such as API
  ///   version, tenant, country, locale, or account id.
  /// - [priority] controls scheduler ordering.
  /// - [deduplicate] shares identical in-flight requests.
  /// - [cancelToken] cancels this request through Dio.
  /// - [cancelTag] enables tag-based cancellation.
  /// - [cancelGroup] enables group cancellation.
  /// - [showLoader] shows a loader while the request runs.
  /// - [loaderWidget] customizes the loader for this request.
  /// - [dismissible] controls the loader barrier.
  /// - [barrierColor] customizes the loader barrier color.
  /// - [context] presents the loader through a specific context.
  /// - [parser] converts the decoded response into [T].
  /// - [isolateParser] decodes and builds [T] in a top-level or static parser
  ///   selected by [threadMode].
  /// - [parseThresholdKb] overrides the auto-thread threshold.
  /// - [dioOptions] are advanced Dio options.
  /// - [onSendProgress] receives upload progress.
  /// - [onReceiveProgress] receives download progress.
  /// - [contentType] overrides request content type.
  /// - [logInChucker] enables or disables Chucker capture for this request.
  /// - [verifyConnectivity] overrides active reachability checks.
  /// - [queueWhenOffline] opts this request into persisted offline replay.
  static Future<NexioResponse<T>> request<T>(
    String method,
    String path, {
    Object? data,
    Map<String, Object?>? queryParameters,
    Map<String, Object?>? headers,
    String? baseUrlOverride,
    EncryptionMode? encryptionMode,
    NexioAuthMode authMode = NexioAuthMode.authenticated,
    ThreadMode? threadMode,
    RetryPolicy? retryPolicy,
    CachePolicy cachePolicy = CachePolicy.networkOnly,
    Duration? cacheTtl,
    Object? cacheKeyExtra,
    RequestPriority priority = RequestPriority.normal,
    bool deduplicate = true,
    CancelToken? cancelToken,
    String? cancelTag,
    String? cancelGroup,
    bool showLoader = false,
    Widget? loaderWidget,
    bool dismissible = false,
    Color? barrierColor,
    BuildContext? context,
    NexioParser<T>? parser,
    NexioIsolateParser<T>? isolateParser,
    int? parseThresholdKb,
    Options? dioOptions,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    String? contentType,
    bool? logInChucker,
    bool? verifyConnectivity,
    bool queueWhenOffline = false,
  }) {
    return _required.request<T>(
      NexioRequestOptions<T>(
        method: method,
        path: path,
        data: data,
        queryParameters: queryParameters,
        headers: headers,
        baseUrlOverride: baseUrlOverride,
        encryptionMode: encryptionMode,
        authMode: authMode,
        threadMode: threadMode,
        retryPolicy: retryPolicy,
        cachePolicy: cachePolicy,
        cacheTtl: cacheTtl,
        cacheKeyExtra: cacheKeyExtra,
        priority: priority,
        deduplicate: deduplicate,
        cancelToken: cancelToken,
        cancelTag: cancelTag,
        cancelGroup: cancelGroup,
        showLoader: showLoader,
        loaderWidget: loaderWidget,
        dismissible: dismissible,
        barrierColor: barrierColor,
        context: context,
        parser: parser,
        isolateParser: isolateParser,
        parseThresholdKb: parseThresholdKb,
        dioOptions: dioOptions,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        contentType: contentType,
        logInChucker: logInChucker,
        verifyConnectivity: verifyConnectivity,
        queueWhenOffline: queueWhenOffline,
      ),
    );
  }

  /// Runs a GET request.
  ///
  /// Parameters follow [request], except [method] is fixed to `GET`.
  static Future<NexioResponse<T>> get<T>(
    String path, {
    Map<String, Object?>? queryParameters,
    Map<String, Object?>? headers,
    String? baseUrlOverride,
    EncryptionMode? encryptionMode,
    NexioAuthMode authMode = NexioAuthMode.authenticated,
    ThreadMode? threadMode,
    RetryPolicy? retryPolicy,
    CachePolicy cachePolicy = CachePolicy.networkOnly,
    Duration? cacheTtl,
    Object? cacheKeyExtra,
    RequestPriority priority = RequestPriority.normal,
    bool deduplicate = true,
    CancelToken? cancelToken,
    String? cancelTag,
    String? cancelGroup,
    bool showLoader = false,
    Widget? loaderWidget,
    bool dismissible = false,
    Color? barrierColor,
    BuildContext? context,
    NexioParser<T>? parser,
    NexioIsolateParser<T>? isolateParser,
    int? parseThresholdKb,
    Options? dioOptions,
    ProgressCallback? onReceiveProgress,
    bool? logInChucker,
    bool? verifyConnectivity,
    bool queueWhenOffline = false,
  }) {
    return request<T>(
      'GET',
      path,
      queryParameters: queryParameters,
      headers: headers,
      baseUrlOverride: baseUrlOverride,
      encryptionMode: encryptionMode,
      authMode: authMode,
      threadMode: threadMode,
      retryPolicy: retryPolicy,
      cachePolicy: cachePolicy,
      cacheTtl: cacheTtl,
      cacheKeyExtra: cacheKeyExtra,
      priority: priority,
      deduplicate: deduplicate,
      cancelToken: cancelToken,
      cancelTag: cancelTag,
      cancelGroup: cancelGroup,
      showLoader: showLoader,
      loaderWidget: loaderWidget,
      dismissible: dismissible,
      barrierColor: barrierColor,
      context: context,
      parser: parser,
      isolateParser: isolateParser,
      parseThresholdKb: parseThresholdKb,
      dioOptions: dioOptions,
      onReceiveProgress: onReceiveProgress,
      logInChucker: logInChucker,
      verifyConnectivity: verifyConnectivity,
      queueWhenOffline: queueWhenOffline,
    );
  }

  /// Runs a POST request.
  ///
  /// Parameters follow [request], except [method] is fixed to `POST`.
  static Future<NexioResponse<T>> post<T>(
    String path, {
    Object? data,
    Map<String, Object?>? queryParameters,
    Map<String, Object?>? headers,
    String? baseUrlOverride,
    EncryptionMode? encryptionMode,
    NexioAuthMode authMode = NexioAuthMode.authenticated,
    ThreadMode? threadMode,
    RetryPolicy? retryPolicy,
    CachePolicy cachePolicy = CachePolicy.networkOnly,
    Duration? cacheTtl,
    Object? cacheKeyExtra,
    RequestPriority priority = RequestPriority.normal,
    bool deduplicate = true,
    CancelToken? cancelToken,
    String? cancelTag,
    String? cancelGroup,
    bool showLoader = false,
    Widget? loaderWidget,
    bool dismissible = false,
    Color? barrierColor,
    BuildContext? context,
    NexioParser<T>? parser,
    NexioIsolateParser<T>? isolateParser,
    int? parseThresholdKb,
    Options? dioOptions,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    String? contentType,
    bool? logInChucker,
    bool? verifyConnectivity,
    bool queueWhenOffline = false,
  }) {
    return request<T>(
      'POST',
      path,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
      baseUrlOverride: baseUrlOverride,
      encryptionMode: encryptionMode,
      authMode: authMode,
      threadMode: threadMode,
      retryPolicy: retryPolicy,
      cachePolicy: cachePolicy,
      cacheTtl: cacheTtl,
      cacheKeyExtra: cacheKeyExtra,
      priority: priority,
      deduplicate: deduplicate,
      cancelToken: cancelToken,
      cancelTag: cancelTag,
      cancelGroup: cancelGroup,
      showLoader: showLoader,
      loaderWidget: loaderWidget,
      dismissible: dismissible,
      barrierColor: barrierColor,
      context: context,
      parser: parser,
      isolateParser: isolateParser,
      parseThresholdKb: parseThresholdKb,
      dioOptions: dioOptions,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      contentType: contentType,
      logInChucker: logInChucker,
      verifyConnectivity: verifyConnectivity,
      queueWhenOffline: queueWhenOffline,
    );
  }

  /// Runs a PUT request.
  ///
  /// Parameters follow [post], except [method] is fixed to `PUT`.
  static Future<NexioResponse<T>> put<T>(
    String path, {
    Object? data,
    Map<String, Object?>? queryParameters,
    Map<String, Object?>? headers,
    String? baseUrlOverride,
    EncryptionMode? encryptionMode,
    NexioAuthMode authMode = NexioAuthMode.authenticated,
    ThreadMode? threadMode,
    RetryPolicy? retryPolicy,
    CachePolicy cachePolicy = CachePolicy.networkOnly,
    Duration? cacheTtl,
    Object? cacheKeyExtra,
    RequestPriority priority = RequestPriority.normal,
    bool deduplicate = true,
    CancelToken? cancelToken,
    String? cancelTag,
    String? cancelGroup,
    bool showLoader = false,
    Widget? loaderWidget,
    bool dismissible = false,
    Color? barrierColor,
    BuildContext? context,
    NexioParser<T>? parser,
    NexioIsolateParser<T>? isolateParser,
    int? parseThresholdKb,
    Options? dioOptions,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    String? contentType,
    bool? logInChucker,
    bool? verifyConnectivity,
    bool queueWhenOffline = false,
  }) {
    return request<T>(
      'PUT',
      path,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
      baseUrlOverride: baseUrlOverride,
      encryptionMode: encryptionMode,
      authMode: authMode,
      threadMode: threadMode,
      retryPolicy: retryPolicy,
      cachePolicy: cachePolicy,
      cacheTtl: cacheTtl,
      cacheKeyExtra: cacheKeyExtra,
      priority: priority,
      deduplicate: deduplicate,
      cancelToken: cancelToken,
      cancelTag: cancelTag,
      cancelGroup: cancelGroup,
      showLoader: showLoader,
      loaderWidget: loaderWidget,
      dismissible: dismissible,
      barrierColor: barrierColor,
      context: context,
      parser: parser,
      isolateParser: isolateParser,
      parseThresholdKb: parseThresholdKb,
      dioOptions: dioOptions,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      contentType: contentType,
      logInChucker: logInChucker,
      verifyConnectivity: verifyConnectivity,
      queueWhenOffline: queueWhenOffline,
    );
  }

  /// Runs a PATCH request.
  ///
  /// Parameters follow [post], except [method] is fixed to `PATCH`.
  static Future<NexioResponse<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, Object?>? queryParameters,
    Map<String, Object?>? headers,
    String? baseUrlOverride,
    EncryptionMode? encryptionMode,
    NexioAuthMode authMode = NexioAuthMode.authenticated,
    ThreadMode? threadMode,
    RetryPolicy? retryPolicy,
    CachePolicy cachePolicy = CachePolicy.networkOnly,
    Duration? cacheTtl,
    Object? cacheKeyExtra,
    RequestPriority priority = RequestPriority.normal,
    bool deduplicate = true,
    CancelToken? cancelToken,
    String? cancelTag,
    String? cancelGroup,
    bool showLoader = false,
    Widget? loaderWidget,
    bool dismissible = false,
    Color? barrierColor,
    BuildContext? context,
    NexioParser<T>? parser,
    NexioIsolateParser<T>? isolateParser,
    int? parseThresholdKb,
    Options? dioOptions,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    String? contentType,
    bool? logInChucker,
    bool? verifyConnectivity,
    bool queueWhenOffline = false,
  }) {
    return request<T>(
      'PATCH',
      path,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
      baseUrlOverride: baseUrlOverride,
      encryptionMode: encryptionMode,
      authMode: authMode,
      threadMode: threadMode,
      retryPolicy: retryPolicy,
      cachePolicy: cachePolicy,
      cacheTtl: cacheTtl,
      cacheKeyExtra: cacheKeyExtra,
      priority: priority,
      deduplicate: deduplicate,
      cancelToken: cancelToken,
      cancelTag: cancelTag,
      cancelGroup: cancelGroup,
      showLoader: showLoader,
      loaderWidget: loaderWidget,
      dismissible: dismissible,
      barrierColor: barrierColor,
      context: context,
      parser: parser,
      isolateParser: isolateParser,
      parseThresholdKb: parseThresholdKb,
      dioOptions: dioOptions,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      contentType: contentType,
      logInChucker: logInChucker,
      verifyConnectivity: verifyConnectivity,
      queueWhenOffline: queueWhenOffline,
    );
  }

  /// Runs a DELETE request.
  ///
  /// Parameters follow [request], except [method] is fixed to `DELETE`.
  static Future<NexioResponse<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, Object?>? queryParameters,
    Map<String, Object?>? headers,
    String? baseUrlOverride,
    EncryptionMode? encryptionMode,
    NexioAuthMode authMode = NexioAuthMode.authenticated,
    ThreadMode? threadMode,
    RetryPolicy? retryPolicy,
    CachePolicy cachePolicy = CachePolicy.networkOnly,
    Duration? cacheTtl,
    Object? cacheKeyExtra,
    RequestPriority priority = RequestPriority.normal,
    bool deduplicate = true,
    CancelToken? cancelToken,
    String? cancelTag,
    String? cancelGroup,
    bool showLoader = false,
    Widget? loaderWidget,
    bool dismissible = false,
    Color? barrierColor,
    BuildContext? context,
    NexioParser<T>? parser,
    NexioIsolateParser<T>? isolateParser,
    int? parseThresholdKb,
    Options? dioOptions,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    String? contentType,
    bool? logInChucker,
    bool? verifyConnectivity,
    bool queueWhenOffline = false,
  }) {
    return request<T>(
      'DELETE',
      path,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
      baseUrlOverride: baseUrlOverride,
      encryptionMode: encryptionMode,
      authMode: authMode,
      threadMode: threadMode,
      retryPolicy: retryPolicy,
      cachePolicy: cachePolicy,
      cacheTtl: cacheTtl,
      cacheKeyExtra: cacheKeyExtra,
      priority: priority,
      deduplicate: deduplicate,
      cancelToken: cancelToken,
      cancelTag: cancelTag,
      cancelGroup: cancelGroup,
      showLoader: showLoader,
      loaderWidget: loaderWidget,
      dismissible: dismissible,
      barrierColor: barrierColor,
      context: context,
      parser: parser,
      isolateParser: isolateParser,
      parseThresholdKb: parseThresholdKb,
      dioOptions: dioOptions,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      contentType: contentType,
      logInChucker: logInChucker,
      verifyConnectivity: verifyConnectivity,
      queueWhenOffline: queueWhenOffline,
    );
  }

  /// Uploads multipart files.
  ///
  /// Parameters:
  /// - [path] is a relative path or absolute URL.
  /// - [files] are upload file descriptors.
  /// - [fields] are additional multipart fields.
  /// - [headers] override or add request headers.
  /// - [baseUrlOverride] replaces the active environment base URL.
  /// - [retryPolicy] overrides global retry behavior.
  /// - [authMode] controls dynamic auth headers and session coordination.
  /// - [priority] controls scheduler ordering.
  /// - [cancelToken] cancels this upload.
  /// - [cancelTag] enables tag-based cancellation.
  /// - [cancelGroup] enables group cancellation.
  /// - [showLoader] shows a loader while upload runs.
  /// - [parser] converts the decoded response into [T].
  /// - [isolateParser] decodes and builds [T] in a top-level or static parser.
  /// - [onSendProgress] receives upload progress.
  /// - [logInChucker] enables or disables Chucker capture for this upload.
  static Future<NexioResponse<T>> upload<T>(
    String path, {
    required List<NexioUploadFile> files,
    Map<String, Object?> fields = const <String, Object?>{},
    Map<String, Object?>? headers,
    String? baseUrlOverride,
    RetryPolicy? retryPolicy,
    NexioAuthMode authMode = NexioAuthMode.authenticated,
    RequestPriority priority = RequestPriority.normal,
    CancelToken? cancelToken,
    String? cancelTag,
    String? cancelGroup,
    bool showLoader = false,
    NexioParser<T>? parser,
    NexioIsolateParser<T>? isolateParser,
    ProgressCallback? onSendProgress,
    bool? logInChucker,
  }) {
    return _required.upload<T>(
      path,
      files: files,
      fields: fields,
      optionsBuilder: (formData) => NexioRequestOptions<T>(
        method: 'POST',
        path: path,
        data: formData,
        headers: headers,
        baseUrlOverride: baseUrlOverride,
        retryPolicy: retryPolicy,
        authMode: authMode,
        priority: priority,
        deduplicate: false,
        cancelToken: cancelToken,
        cancelTag: cancelTag,
        cancelGroup: cancelGroup,
        showLoader: showLoader,
        parser: parser,
        isolateParser: isolateParser,
        onSendProgress: onSendProgress,
        contentType: Headers.multipartFormDataContentType,
        logInChucker: logInChucker,
      ),
    );
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
  /// - [autoStart] starts immediately. Defaults to `true`.
  /// - [logInChucker] enables or disables Chucker capture for this download.
  /// - [authMode] controls dynamic auth headers for this download.
  static NexioDownloadTask download(
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
    return _required.download(
      path,
      destinationPath: destinationPath,
      queryParameters: queryParameters,
      headers: headers,
      baseUrlOverride: baseUrlOverride,
      onProgress: onProgress,
      autoStart: autoStart,
      logInChucker: logInChucker,
      authMode: authMode,
    );
  }

  /// Cancels requests with [tag].
  ///
  /// Parameters:
  /// - [tag] identifies requests to cancel.
  /// - [reason] explains why cancellation was requested.
  static void cancelTag(String tag, {String reason = 'Cancelled by tag'}) {
    _required.cancellationRegistry.cancelTag(tag, reason: reason);
  }

  /// Cancels requests with [group].
  ///
  /// Parameters:
  /// - [group] identifies requests to cancel.
  /// - [reason] explains why cancellation was requested.
  static void cancelGroup(String group,
      {String reason = 'Cancelled by group'}) {
    _required.cancellationRegistry.cancelGroup(group, reason: reason);
  }

  /// Clears memory and disk cache.
  static Future<void> clearCache() => _required.cacheStore.clear();

  /// Opens Chucker logs or Nexio fallback logs.
  ///
  /// Parameters:
  /// - [context] is required for the fallback log sheet.
  static void showLogs(BuildContext context) {
    _required.showLogs(context);
  }

  static NexioClient get _required {
    final client = _client;
    if (client == null) {
      throw const NexioNotInitializedException();
    }
    return client;
  }
}
