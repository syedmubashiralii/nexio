import '../models/nexio_response.dart';

/// Base exception type thrown by Nexio.
class NexioException implements Exception {
  /// Creates a Nexio exception.
  ///
  /// Parameters:
  /// - [message] describes the failure in developer-readable language.
  /// - [cause] stores the original error when Nexio wraps another exception.
  const NexioException(this.message, {this.cause});

  /// Human-readable failure message.
  final String message;

  /// Original exception or error, when available.
  final Object? cause;

  @override
  String toString() => 'NexioException: $message';
}

/// Thrown when Nexio is used before initialization.
class NexioNotInitializedException extends NexioException {
  /// Creates a not-initialized exception.
  const NexioNotInitializedException()
      : super('Call Nexio.initialize(...) before making requests.');
}

/// Thrown when the selected environment has no base URL.
class NexioEnvironmentException extends NexioException {
  /// Creates an environment configuration exception.
  ///
  /// Parameters:
  /// - [message] explains which environment configuration is invalid.
  const NexioEnvironmentException(super.message);
}

/// Thrown when cache-only reads cannot find a valid entry.
class NexioCacheMissException extends NexioException {
  /// Creates a cache miss exception.
  ///
  /// Parameters:
  /// - [cacheKey] is the internal key that missed.
  const NexioCacheMissException(this.cacheKey)
      : super('No valid Nexio cache entry exists for this request.');

  /// Internal cache key that missed.
  final String cacheKey;
}

/// Thrown when an HTTP response status is not successful.
class NexioHttpException<T> extends NexioException {
  /// Creates an HTTP exception.
  ///
  /// Parameters:
  /// - [response] contains the parsed non-success response.
  NexioHttpException(this.response)
      : super('HTTP request failed with status ${response.statusCode}.');

  /// Non-success response returned by the server.
  final NexioResponse<T> response;
}

/// Thrown when Nexio stores a request for offline replay.
class NexioOfflineQueuedException extends NexioException {
  /// Creates an offline queued exception.
  ///
  /// Parameters:
  /// - [queueId] identifies the stored request.
  const NexioOfflineQueuedException(this.queueId)
      : super('Request was queued because the device is offline.');

  /// Identifier of the queued request.
  final String queueId;
}

/// Thrown when an active connectivity check reports no reachable network.
class NexioOfflineException extends NexioException {
  /// Creates an offline exception.
  const NexioOfflineException()
      : super('No reachable network is available for this request.');
}

/// Thrown when a request cannot be safely serialized for offline replay.
class NexioOfflineQueueSerializationException extends NexioException {
  /// Creates an offline queue serialization exception.
  ///
  /// Parameters:
  /// - [cause] is the original JSON serialization error.
  const NexioOfflineQueueSerializationException({super.cause})
      : super(
          'Offline replay supports JSON-safe request data, query parameters, '
          'and persisted headers only.',
        );
}

/// Thrown when protected traffic is blocked after session expiry.
class NexioSessionExpiredException extends NexioException {
  /// Creates a session-expired exception.
  const NexioSessionExpiredException()
      : super(
          'The Nexio authentication session is expired. Call '
          'Nexio.resetAuthSession() after the app establishes a new session.',
        );
}

/// Thrown when encryption configuration is missing or invalid.
class NexioEncryptionException extends NexioException {
  /// Creates an encryption exception.
  ///
  /// Parameters:
  /// - [message] explains the invalid encryption state.
  /// - [cause] stores the original crypto error when available.
  const NexioEncryptionException(super.message, {super.cause});
}
