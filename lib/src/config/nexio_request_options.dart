import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../parser/nexio_parser.dart';
import 'environment.dart';
import 'retry_policy.dart';

/// Immutable options for one Nexio request.
class NexioRequestOptions<T> {
  /// Creates per-request options.
  ///
  /// Parameters:
  /// - [method] is the HTTP method, such as `GET` or `POST`.
  /// - [path] is a relative path or absolute URL.
  /// - [data] is the request body. Maps/lists are sent as JSON by default.
  /// - [queryParameters] are appended to the URL.
  /// - [headers] override or add to global headers.
  /// - [baseUrlOverride] replaces the active environment base URL for this
  ///   request only.
  /// - [encryptionMode] overrides global encryption for this request.
  /// - [threadMode] overrides the global parser thread mode.
  /// - [retryPolicy] overrides the global retry policy.
  /// - [cachePolicy] controls cache behavior. Defaults to network only.
  /// - [cacheTtl] controls this response's cache lifetime.
  /// - [cacheKeyExtra] namespaces the cache key with app-owned metadata such
  ///   as API version, tenant, country, locale, or account id.
  /// - [priority] controls scheduler ordering. Defaults to normal.
  /// - [deduplicate] shares one in-flight response for identical requests.
  ///   Defaults to `true`.
  /// - [cancelToken] is a Dio cancellation token supplied by the caller.
  /// - [cancelTag] groups a single logical family of requests for cancellation.
  /// - [cancelGroup] groups a broader set of requests for cancellation.
  /// - [showLoader] shows the configured loader while the request is running.
  /// - [loaderWidget] replaces Nexio's default loader for this request.
  /// - [dismissible] controls whether the loader barrier can be dismissed.
  /// - [barrierColor] customizes the loader barrier color.
  /// - [context] is used to present a loader when no global navigator key exists.
  /// - [parser] converts the decrypted response into [T].
  /// - [parseThresholdKb] overrides the global auto-thread threshold.
  /// - [dioOptions] are merged into Dio's per-request options.
  /// - [onSendProgress] receives upload progress.
  /// - [onReceiveProgress] receives download progress.
  /// - [contentType] overrides Dio's request content type.
  /// - [logInChucker] overrides the global Chucker capture default for this
  ///   request. Use `false` for sensitive endpoints.
  const NexioRequestOptions({
    required this.method,
    required this.path,
    this.data,
    this.queryParameters,
    this.headers,
    this.baseUrlOverride,
    this.encryptionMode,
    this.threadMode,
    this.retryPolicy,
    this.cachePolicy = CachePolicy.networkOnly,
    this.cacheTtl,
    this.cacheKeyExtra,
    this.priority = RequestPriority.normal,
    this.deduplicate = true,
    this.cancelToken,
    this.cancelTag,
    this.cancelGroup,
    this.showLoader = false,
    this.loaderWidget,
    this.dismissible = false,
    this.barrierColor,
    this.context,
    this.parser,
    this.parseThresholdKb,
    this.dioOptions,
    this.onSendProgress,
    this.onReceiveProgress,
    this.contentType,
    this.logInChucker,
  });

  /// HTTP method.
  final String method;

  /// Relative path or absolute URL.
  final String path;

  /// Request body.
  final Object? data;

  /// Query parameters appended to the request URL.
  final Map<String, Object?>? queryParameters;

  /// Request-specific headers.
  final Map<String, Object?>? headers;

  /// Request-specific base URL.
  final String? baseUrlOverride;

  /// Request-specific encryption mode.
  final EncryptionMode? encryptionMode;

  /// Request-specific parser thread mode.
  final ThreadMode? threadMode;

  /// Request-specific retry policy.
  final RetryPolicy? retryPolicy;

  /// Request-specific cache behavior.
  final CachePolicy cachePolicy;

  /// Request-specific cache time-to-live.
  final Duration? cacheTtl;

  /// App-owned metadata included in this request's cache key.
  final Object? cacheKeyExtra;

  /// Scheduler priority for this request.
  final RequestPriority priority;

  /// Whether identical in-flight requests share one response.
  final bool deduplicate;

  /// Caller-supplied Dio cancellation token.
  final CancelToken? cancelToken;

  /// Cancellation tag for this request.
  final String? cancelTag;

  /// Cancellation group for this request.
  final String? cancelGroup;

  /// Whether to show a loader while this request runs.
  final bool showLoader;

  /// Custom loader widget for this request.
  final Widget? loaderWidget;

  /// Whether the loader barrier can be dismissed.
  final bool dismissible;

  /// Loader barrier color.
  final Color? barrierColor;

  /// Build context used for loader presentation.
  final BuildContext? context;

  /// Parser used to build [T] from the decoded response.
  final NexioParser<T>? parser;

  /// Auto-thread threshold override in kilobytes.
  final int? parseThresholdKb;

  /// Advanced Dio options merged into the request.
  final Options? dioOptions;

  /// Upload progress callback.
  final ProgressCallback? onSendProgress;

  /// Download progress callback.
  final ProgressCallback? onReceiveProgress;

  /// Request content type override.
  final String? contentType;

  /// Whether Chucker should capture this request.
  final bool? logInChucker;
}
