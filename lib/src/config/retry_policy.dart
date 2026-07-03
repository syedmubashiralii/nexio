import 'package:dio/dio.dart';

import 'environment.dart';

/// Defines when Nexio should retry a failed request.
class RetryPolicy {
  /// Creates a retry policy.
  ///
  /// Parameters:
  /// - [retries] is the number of retry attempts after the first request.
  ///   Defaults to `0`, which disables retries.
  /// - [strategy] controls retry delay calculation. Defaults to exponential.
  /// - [delay] is the first retry delay. Defaults to 300 milliseconds.
  /// - [maxDelay] caps exponential backoff. Defaults to five seconds.
  /// - [retryableStatusCodes] are HTTP statuses that should be retried.
  ///   Defaults to common transient statuses.
  /// - [retryableExceptionTypes] are Dio exception types that should be
  ///   retried. Defaults to timeout, connection, and unknown transport errors.
  const RetryPolicy({
    this.retries = 0,
    this.strategy = RetryStrategy.exponential,
    this.delay = const Duration(milliseconds: 300),
    this.maxDelay = const Duration(seconds: 5),
    this.retryableStatusCodes = const {408, 429, 500, 502, 503, 504},
    this.retryableExceptionTypes = const {
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.unknown,
    },
  });

  /// A policy that never retries.
  static const RetryPolicy none = RetryPolicy();

  /// Number of retry attempts after the first request.
  final int retries;

  /// Retry delay calculation strategy.
  final RetryStrategy strategy;

  /// First retry delay for fixed or exponential backoff.
  final Duration delay;

  /// Maximum delay allowed for exponential backoff.
  final Duration maxDelay;

  /// HTTP status codes that should be retried.
  final Set<int> retryableStatusCodes;

  /// Dio transport exception types that should be retried.
  final Set<DioExceptionType> retryableExceptionTypes;

  /// Returns whether [statusCode] can be retried.
  bool shouldRetryStatus(int? statusCode) {
    return statusCode != null && retryableStatusCodes.contains(statusCode);
  }

  /// Returns whether [error] can be retried.
  bool shouldRetryException(Object error) {
    return error is DioException &&
        retryableExceptionTypes.contains(error.type);
  }

  /// Returns the delay before retry attempt [attempt].
  ///
  /// Parameters:
  /// - [attempt] is one-based. The first retry attempt should pass `1`.
  Duration delayForAttempt(int attempt) {
    if (strategy == RetryStrategy.fixed) {
      return delay;
    }
    final factor = 1 << (attempt - 1).clamp(0, 30);
    final milliseconds = delay.inMilliseconds * factor;
    return Duration(
      milliseconds: milliseconds.clamp(0, maxDelay.inMilliseconds),
    );
  }
}
