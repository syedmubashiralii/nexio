import 'dart:async';
import 'dart:collection';

import '../config/environment.dart';

/// Schedules requests while respecting priority and concurrency.
class NexioRequestScheduler {
  /// Creates a request scheduler.
  ///
  /// Parameters:
  /// - [maxConcurrentRequests] is the number of requests allowed to run at once.
  NexioRequestScheduler({required int maxConcurrentRequests})
      : _maxConcurrentRequests = maxConcurrentRequests.clamp(1, 64);

  final int _maxConcurrentRequests;
  final Queue<_ScheduledRequest<Object?>> _high =
      Queue<_ScheduledRequest<Object?>>();
  final Queue<_ScheduledRequest<Object?>> _normal =
      Queue<_ScheduledRequest<Object?>>();
  final Queue<_ScheduledRequest<Object?>> _low =
      Queue<_ScheduledRequest<Object?>>();
  int _running = 0;

  /// Schedules [operation] at [priority].
  ///
  /// Parameters:
  /// - [priority] decides which queue receives the work.
  /// - [operation] performs the request and returns a result.
  Future<T> schedule<T>(
    RequestPriority priority,
    Future<T> Function() operation,
  ) {
    final completer = Completer<T>();
    final item = _ScheduledRequest<T>(operation, completer);
    _queueFor(priority).add(item as _ScheduledRequest<Object?>);
    _pump();
    return completer.future;
  }

  Queue<_ScheduledRequest<Object?>> _queueFor(RequestPriority priority) {
    return switch (priority) {
      RequestPriority.high => _high,
      RequestPriority.normal => _normal,
      RequestPriority.low => _low,
    };
  }

  void _pump() {
    while (_running < _maxConcurrentRequests) {
      final item = _next();
      if (item == null) {
        return;
      }
      _running += 1;
      unawaited(_run(item));
    }
  }

  _ScheduledRequest<Object?>? _next() {
    if (_high.isNotEmpty) {
      return _high.removeFirst();
    }
    if (_normal.isNotEmpty) {
      return _normal.removeFirst();
    }
    if (_low.isNotEmpty) {
      return _low.removeFirst();
    }
    return null;
  }

  Future<void> _run(_ScheduledRequest<Object?> item) async {
    try {
      item.completer.complete(await item.operation());
    } catch (error, stackTrace) {
      item.completer.completeError(error, stackTrace);
    } finally {
      _running -= 1;
      _pump();
    }
  }
}

class _ScheduledRequest<T> {
  _ScheduledRequest(this.operation, this.completer);

  final Future<T> Function() operation;
  final Completer<T> completer;
}
