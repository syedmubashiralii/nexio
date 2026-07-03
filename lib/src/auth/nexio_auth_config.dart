import 'dart:async';

import 'package:dio/dio.dart';

/// Decision returned by [NexioAuthConfig.decide].
enum NexioAuthDecision {
  /// Continue normal response parsing.
  proceed,

  /// Run the configured refresh callback and retry the request once refreshed.
  refreshAndRetry,

  /// Stop protected traffic and notify the app that the session is expired.
  expireSession,
}

/// Context passed to auth/session callbacks.
class NexioAuthSignal {
  /// Creates an auth signal.
  ///
  /// Parameters:
  /// - [statusCode] is the HTTP status code returned by Dio.
  /// - [data] is the latest response body available to Nexio. For encrypted
  ///   APIs this may be raw encrypted data before decryption, then decrypted
  ///   data after response decryption.
  /// - [url] is the resolved request URL.
  /// - [environment] is the active environment when the response arrived.
  /// - [requestOptions] are Dio request options for the failed request.
  /// - [refreshAttempt] is zero for the first response and increments for
  ///   refresh retries.
  const NexioAuthSignal({
    required this.statusCode,
    required this.data,
    required this.url,
    required this.environment,
    required this.requestOptions,
    required this.refreshAttempt,
  });

  /// HTTP status code from the server.
  final int? statusCode;

  /// Raw or decrypted response body available at the decision point.
  final Object? data;

  /// Resolved request URL.
  final String url;

  /// Active Nexio environment.
  final String environment;

  /// Dio request options for the response.
  final RequestOptions requestOptions;

  /// Number of refresh retries already attempted for this request.
  final int refreshAttempt;
}

/// Backend-agnostic auth/session coordination for enterprise apps.
class NexioAuthConfig {
  /// Creates auth/session configuration.
  ///
  /// Parameters:
  /// - [headersProvider] returns dynamic headers before each request. Use it for
  ///   bearer tokens, gateway tokens, device identifiers, app version, locale,
  ///   tenant, country, or channel headers. Defaults to no dynamic headers.
  /// - [decide] inspects a response and decides whether to continue, refresh,
  ///   or expire the session. Defaults to refreshing HTTP 401 only when
  ///   [refresh] is provided.
  /// - [refresh] performs app-owned refresh logic, such as access-token or
  ///   gateway-token regeneration. Nexio coordinates this callback but does not
  ///   know backend credentials. Return `true` when future requests should be
  ///   retried with fresh headers.
  /// - [onSessionExpired] is called when refresh fails or [decide] returns
  ///   [NexioAuthDecision.expireSession].
  /// - [maxRefreshAttempts] limits refresh retries per request. Defaults to `1`.
  /// - [queueWhileRefreshing] makes protected requests wait while another
  ///   request is refreshing tokens. Defaults to `true`.
  const NexioAuthConfig({
    this.headersProvider,
    this.decide,
    this.refresh,
    this.onSessionExpired,
    this.maxRefreshAttempts = 1,
    this.queueWhileRefreshing = true,
  });

  /// Dynamic headers evaluated before each request.
  final FutureOr<Map<String, Object?>> Function()? headersProvider;

  /// Backend-specific response classifier.
  final NexioAuthDecision Function(NexioAuthSignal signal)? decide;

  /// App-owned refresh implementation coordinated by Nexio.
  final FutureOr<bool> Function(NexioAuthSignal signal)? refresh;

  /// Called when protected traffic should stop and the app should re-auth.
  final void Function(NexioAuthSignal signal)? onSessionExpired;

  /// Maximum refresh retries allowed for one request.
  final int maxRefreshAttempts;

  /// Whether requests wait for an already-running refresh before sending.
  final bool queueWhileRefreshing;

  /// Returns the auth decision for [signal].
  ///
  /// Parameters:
  /// - [signal] contains the response status and body for the decision point.
  NexioAuthDecision decisionFor(NexioAuthSignal signal) {
    final custom = decide?.call(signal);
    if (custom != null) {
      return custom;
    }
    if (signal.statusCode == 401 && refresh != null) {
      return NexioAuthDecision.refreshAndRetry;
    }
    return NexioAuthDecision.proceed;
  }
}
