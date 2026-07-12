import 'package:dio/dio.dart';

/// Creates a fresh user interceptor for each cached Dio client.
typedef NexioInterceptorFactory = Interceptor Function();

/// Request metadata keys shared by Nexio's built-in interceptors.
abstract final class NexioRequestMetadata {
  /// Per-request encryption mode name.
  static const String encryptionMode = 'nexio.encryptionMode';

  /// Whether Chucker should capture this request.
  static const String logInChucker = 'nexio.logInChucker';

  /// Named environment captured when the request was created.
  static const String environmentName = 'nexio.environmentName';

  /// Whether authentication coordination applies to this request.
  static const String authMode = 'nexio.authMode';

  /// Response decryption duration in microseconds.
  static const String decryptDurationMicros = 'nexio.decryptDurationMicros';
}
