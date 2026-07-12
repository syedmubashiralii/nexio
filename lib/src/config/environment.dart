/// Configuration for one user-defined backend environment.
class NexioEnvironment {
  /// Creates an environment configuration.
  ///
  /// Parameters:
  /// - [baseUrl] is the absolute base URL used for relative request paths.
  /// - [headers] are environment-specific headers merged before dynamic and
  ///   per-request headers. Defaults to an empty map.
  /// - [connectTimeout] limits connection establishment. Defaults to 30 seconds.
  /// - [sendTimeout] limits request-body transmission. Defaults to 30 seconds.
  /// - [receiveTimeout] limits response waiting. Defaults to 30 seconds.
  /// - [extra] stores app-owned environment metadata such as tenant or region.
  const NexioEnvironment({
    required this.baseUrl,
    this.headers = const <String, Object?>{},
    this.connectTimeout = const Duration(seconds: 30),
    this.sendTimeout = const Duration(seconds: 30),
    this.receiveTimeout = const Duration(seconds: 30),
    this.extra = const <String, Object?>{},
  });

  /// Absolute base URL for this environment.
  final String baseUrl;

  /// Headers applied to requests in this environment.
  final Map<String, Object?> headers;

  /// Connection timeout for this environment.
  final Duration connectTimeout;

  /// Send timeout for this environment.
  final Duration sendTimeout;

  /// Receive timeout for this environment.
  final Duration receiveTimeout;

  /// App-owned environment metadata.
  final Map<String, Object?> extra;
}

/// Controls whether and how request or response payloads are encrypted.
enum EncryptionMode {
  /// Sends and receives payloads without encryption.
  none,

  /// Uses AES-CBC with a configured key and IV.
  aesCbc,

  /// Uses AES-GCM with a configured key and generated nonce.
  aesGcm,
}

/// Controls where Nexio parses response payloads.
enum ThreadMode {
  /// Parses small payloads on the main isolate and large payloads off-isolate.
  auto,

  /// Always parses on the main isolate.
  main,

  /// Parses supported built-in payloads on a background isolate.
  background,
}

/// Defines how Nexio should read and write cached responses.
enum CachePolicy {
  /// Always hits the network and does not read from cache.
  networkOnly,

  /// Reads only from cache and fails when no valid cache entry exists.
  cacheOnly,

  /// Returns cache first, falling back to the network on a cache miss.
  cacheFirst,

  /// Hits the network first, falling back to cache if the request fails.
  networkFirst,
}

/// Controls how queued requests are ordered by the scheduler.
enum RequestPriority {
  /// Runs before normal and low priority work.
  high,

  /// Default priority for regular user-initiated requests.
  normal,

  /// Runs after high and normal priority work.
  low,
}

/// Controls whether Nexio applies authentication coordination to a request.
enum NexioAuthMode {
  /// Applies dynamic auth headers, refresh coordination, and the session gate.
  authenticated,

  /// Skips dynamic auth headers, refresh classification, and the session gate.
  ///
  /// Use this for sign-in, registration, public configuration, and app-owned
  /// refresh endpoints.
  anonymous,
}

/// Determines how retry delays are calculated.
enum RetryStrategy {
  /// Retries use the same delay each time.
  fixed,

  /// Retries multiply the delay after each failed attempt.
  exponential,
}
