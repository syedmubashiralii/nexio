import 'dart:async';

/// Aggregated network outcome categories.
enum NexioHealthOutcome {
  /// Successful network response.
  ok,

  /// Device was offline or the connection could not be established.
  offline,

  /// Connection, send, or receive timeout.
  timeout,

  /// Request was cancelled.
  cancelled,

  /// Authentication refresh was requested.
  authRefresh,

  /// Authentication could not recover and the session expired.
  unauthorized,

  /// Server returned a non-success response.
  serverError,
}

/// Immutable aggregate of endpoint health outcomes.
class NexioHealthSnapshot {
  /// Creates a health snapshot.
  ///
  /// Parameters:
  /// - [createdAt] is when the snapshot was generated.
  /// - [counts] maps sanitized endpoint paths to outcome counters.
  const NexioHealthSnapshot({
    required this.createdAt,
    required this.counts,
  });

  /// Snapshot creation time.
  final DateTime createdAt;

  /// Outcome counters by endpoint path.
  final Map<String, Map<NexioHealthOutcome, int>> counts;

  /// Total outcomes represented by this snapshot.
  int get total => counts.values.fold<int>(
        0,
        (sum, outcomes) =>
            sum + outcomes.values.fold<int>(0, (inner, count) => inner + count),
      );
}

/// Controls aggregated network health collection and flushing.
class NexioHealthConfig {
  /// Creates health monitoring configuration.
  ///
  /// Parameters:
  /// - [enabled] enables aggregation. Defaults to `true`.
  /// - [flushEveryRequests] flushes after this many recorded outcomes.
  ///   Defaults to `25`.
  /// - [flushInterval] flushes after this duration when another outcome is
  ///   recorded. Defaults to 15 minutes.
  /// - [onFlush] receives an aggregate snapshot. The app decides whether to
  ///   send it to Firebase, OpenTelemetry, Datadog, Sentry, or another service.
  const NexioHealthConfig({
    this.enabled = true,
    this.flushEveryRequests = 25,
    this.flushInterval = const Duration(minutes: 15),
    this.onFlush,
  });

  /// Whether network health is collected.
  final bool enabled;

  /// Number of outcomes that triggers a flush.
  final int flushEveryRequests;

  /// Maximum interval between eligible flushes.
  final Duration flushInterval;

  /// App-owned snapshot destination.
  final FutureOr<void> Function(NexioHealthSnapshot snapshot)? onFlush;
}

/// Collects low-cardinality network health without storing payloads or tokens.
class NexioHealthMonitor {
  /// Creates a health monitor.
  ///
  /// Parameters:
  /// - [config] controls collection and flush behavior.
  NexioHealthMonitor(this.config);

  /// Health monitoring configuration.
  final NexioHealthConfig config;

  final Map<String, Map<NexioHealthOutcome, int>> _counts =
      <String, Map<NexioHealthOutcome, int>>{};
  final StreamController<NexioHealthSnapshot> _snapshots =
      StreamController<NexioHealthSnapshot>.broadcast();
  DateTime _lastFlush = DateTime.now();
  int _sinceFlush = 0;

  /// Stream of flushed health snapshots.
  Stream<NexioHealthSnapshot> get snapshots => _snapshots.stream;

  /// Current unflushed health snapshot.
  NexioHealthSnapshot get current => NexioHealthSnapshot(
        createdAt: DateTime.now(),
        counts: _copyCounts(),
      );

  /// Records one [outcome] for [url].
  ///
  /// Parameters:
  /// - [url] is reduced to its path to avoid high-cardinality hosts and queries.
  /// - [outcome] is the classified network result.
  void record(String url, NexioHealthOutcome outcome) {
    if (!config.enabled) {
      return;
    }
    final endpoint = _endpointPath(url);
    final outcomes = _counts.putIfAbsent(
      endpoint,
      () => <NexioHealthOutcome, int>{},
    );
    outcomes[outcome] = (outcomes[outcome] ?? 0) + 1;
    _sinceFlush += 1;
    unawaited(flushIfNeeded());
  }

  /// Flushes when count or interval thresholds are reached.
  Future<void> flushIfNeeded() async {
    if (_counts.isEmpty ||
        (_sinceFlush < config.flushEveryRequests &&
            DateTime.now().difference(_lastFlush) < config.flushInterval)) {
      return;
    }
    await flush();
  }

  /// Flushes the current aggregate immediately.
  Future<void> flush() async {
    if (_counts.isEmpty) {
      return;
    }
    final snapshot = current;
    _counts.clear();
    _sinceFlush = 0;
    _lastFlush = DateTime.now();
    if (!_snapshots.isClosed) {
      _snapshots.add(snapshot);
    }
    await Future.value(config.onFlush?.call(snapshot));
  }

  Map<String, Map<NexioHealthOutcome, int>> _copyCounts() {
    return _counts.map(
      (endpoint, outcomes) => MapEntry(
        endpoint,
        Map<NexioHealthOutcome, int>.unmodifiable(outcomes),
      ),
    );
  }

  String _endpointPath(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) {
      return value.split('?').first;
    }
    return uri.path.isEmpty ? '/' : uri.path;
  }
}
