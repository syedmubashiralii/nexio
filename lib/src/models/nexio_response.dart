import 'package:dio/dio.dart';

import 'nexio_metrics.dart';

/// A typed response returned by Nexio.
class NexioResponse<T> {
  /// Creates a typed Nexio response.
  ///
  /// Parameters:
  /// - [data] is the parsed response body.
  /// - [statusCode] is the HTTP status code when the response came from Dio.
  /// - [statusMessage] is Dio's status text when available.
  /// - [headers] are response headers. Cache responses restore stored headers.
  /// - [metrics] contains network, decrypt, parse, and total durations.
  /// - [fromCache] is `true` when this response came from Nexio cache.
  /// - [requestOptions] are Dio request options when a network request ran.
  const NexioResponse({
    required this.data,
    required this.statusCode,
    required this.statusMessage,
    required this.headers,
    required this.metrics,
    required this.fromCache,
    this.requestOptions,
  });

  /// Parsed response data.
  final T data;

  /// HTTP status code, or `null` when unavailable.
  final int? statusCode;

  /// HTTP status message, or `null` when unavailable.
  final String? statusMessage;

  /// Response headers.
  final Map<String, List<String>> headers;

  /// Request lifecycle timing metrics.
  final NexioMetrics metrics;

  /// Whether this response was served from cache.
  final bool fromCache;

  /// Dio request options for network responses.
  final RequestOptions? requestOptions;
}
