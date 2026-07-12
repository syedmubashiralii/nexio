import 'dart:async';

import 'package:dio/dio.dart';

import '../config/environment.dart';
import 'nexio_interceptor.dart';

/// Applies global, environment, dynamic, and request headers in precedence order.
class NexioContextInterceptor extends Interceptor {
  /// Creates the context interceptor.
  ///
  /// Parameters:
  /// - [defaultHeaders] are global headers.
  /// - [environmentProvider] returns the current environment configuration.
  /// - [dynamicHeadersProvider] returns tokens and context before each request.
  NexioContextInterceptor({
    required this.defaultHeaders,
    required this.environmentProvider,
    this.dynamicHeadersProvider,
  });

  /// Global headers.
  final Map<String, Object?> defaultHeaders;

  /// Current environment provider.
  final NexioEnvironment Function(String? name) environmentProvider;

  /// Dynamic headers provider.
  final FutureOr<Map<String, Object?>> Function()? dynamicHeadersProvider;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final requestHeaders = Map<String, Object?>.from(options.headers);
      final environmentName =
          options.extra[NexioRequestMetadata.environmentName] as String?;
      final authMode =
          options.extra[NexioRequestMetadata.authMode] as NexioAuthMode? ??
              NexioAuthMode.authenticated;
      final dynamicHeaders =
          dynamicHeadersProvider == null || authMode == NexioAuthMode.anonymous
              ? const <String, Object?>{}
              : await Future.value(dynamicHeadersProvider!());
      options.headers
        ..clear()
        ..addAll(defaultHeaders)
        ..addAll(environmentProvider(environmentName).headers)
        ..addAll(dynamicHeaders)
        ..addAll(requestHeaders);
      handler.next(options);
    } catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
