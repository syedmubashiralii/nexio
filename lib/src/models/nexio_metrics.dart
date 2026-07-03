/// Timing metrics captured for a Nexio response.
class NexioMetrics {
  /// Creates immutable response timing metrics.
  ///
  /// Parameters:
  /// - [networkDuration] measures the Dio request and response time.
  /// - [decryptDuration] measures response decryption time.
  /// - [parseDuration] measures response parsing time.
  /// - [totalDuration] measures the whole request lifecycle.
  const NexioMetrics({
    required this.networkDuration,
    required this.decryptDuration,
    required this.parseDuration,
    required this.totalDuration,
  });

  /// Time spent waiting for the network layer.
  final Duration networkDuration;

  /// Time spent decrypting the response payload.
  final Duration decryptDuration;

  /// Time spent parsing the response body into the requested type.
  final Duration parseDuration;

  /// Total request lifecycle duration.
  final Duration totalDuration;

  /// Metrics with every duration set to zero.
  static const NexioMetrics zero = NexioMetrics(
    networkDuration: Duration.zero,
    decryptDuration: Duration.zero,
    parseDuration: Duration.zero,
    totalDuration: Duration.zero,
  );
}
