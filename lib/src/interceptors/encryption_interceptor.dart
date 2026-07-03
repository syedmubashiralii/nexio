import 'package:dio/dio.dart';

import '../config/environment.dart';
import '../encryption/encryption_engine.dart';
import '../errors/nexio_exception.dart';
import 'nexio_interceptor.dart';

/// Encrypts request data and decrypts response data inside Dio's pipeline.
class NexioEncryptionInterceptor extends Interceptor {
  /// Creates the encryption interceptor.
  ///
  /// Parameters:
  /// - [engine] contains built-in and user-registered ciphers.
  NexioEncryptionInterceptor(this.engine);

  /// Encryption engine used by this interceptor.
  final NexioEncryptionEngine engine;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final mode = _modeFor(options);
    if (mode == EncryptionMode.none || options.data == null) {
      handler.next(options);
      return;
    }
    if (options.data is FormData) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: const NexioEncryptionException(
            'Built-in encryption does not support multipart FormData. '
            'Encrypt files before upload or register a custom cipher.',
          ),
        ),
      );
      return;
    }

    try {
      options.data = await engine.encryptRequest(options.data, mode);
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

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    try {
      await _decryptResponse(response);
      handler.next(response);
    } catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    if (response == null) {
      handler.next(err);
      return;
    }
    try {
      await _decryptResponse(response);
    } catch (_) {
      // Preserve the original Dio error when an error response is not encrypted.
    }
    handler.next(err);
  }

  Future<void> _decryptResponse(Response<dynamic> response) async {
    final mode = _modeFor(response.requestOptions);
    if (mode == EncryptionMode.none || response.data == null) {
      return;
    }
    final stopwatch = Stopwatch()..start();
    response.data = await engine.decryptResponse(response.data, mode);
    stopwatch.stop();
    response.requestOptions.extra[NexioRequestMetadata.decryptDurationMicros] =
        stopwatch.elapsedMicroseconds;
  }

  EncryptionMode _modeFor(RequestOptions options) {
    final value = options.extra[NexioRequestMetadata.encryptionMode];
    if (value is EncryptionMode) {
      return value;
    }
    if (value is String) {
      return EncryptionMode.values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => EncryptionMode.none,
      );
    }
    return EncryptionMode.none;
  }
}
