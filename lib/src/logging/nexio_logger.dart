import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// One captured network log entry.
class NexioLogEntry {
  /// Creates a log entry.
  ///
  /// Parameters:
  /// - [message] is the compact log message.
  /// - [timestamp] records when the entry was created.
  const NexioLogEntry({
    required this.message,
    required this.timestamp,
  });

  /// Compact log message.
  final String message;

  /// Time when the log entry was captured.
  final DateTime timestamp;
}

/// Lightweight request logger used by Nexio and tests.
class NexioLogger extends Interceptor {
  /// Creates a logger.
  ///
  /// Parameters:
  /// - [enabled] controls whether entries are captured and printed.
  /// - [maxEntries] limits in-memory log retention.
  NexioLogger({
    required this.enabled,
    this.maxEntries = 300,
  });

  /// Whether logging is active.
  final bool enabled;

  /// Maximum retained entries.
  final int maxEntries;

  final List<NexioLogEntry> _entries = <NexioLogEntry>[];
  final Map<RequestOptions, Stopwatch> _timers = <RequestOptions, Stopwatch>{};

  /// Retained log entries.
  List<NexioLogEntry> get entries => List<NexioLogEntry>.unmodifiable(_entries);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      _timers[options] = Stopwatch()..start();
      _add(
        'REQUEST ${options.method} ${options.uri} '
        'headers=${jsonEncode(options.headers)} data=${_safe(options.data)}',
      );
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    if (enabled) {
      final elapsed = _timers.remove(response.requestOptions)?.elapsed;
      _add(
        'RESPONSE ${response.statusCode} ${response.requestOptions.uri} '
        'time=${elapsed?.inMilliseconds ?? 0}ms data=${_safe(response.data)}',
      );
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled) {
      final elapsed = _timers.remove(err.requestOptions)?.elapsed;
      _add(
        'ERROR ${err.type} ${err.requestOptions.uri} '
        'time=${elapsed?.inMilliseconds ?? 0}ms message=${err.message}',
      );
    }
    super.onError(err, handler);
  }

  void _add(String message) {
    final entry = NexioLogEntry(message: message, timestamp: DateTime.now());
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    debugPrint('[Nexio] $message');
  }

  String _safe(Object? value) {
    final text = value is String ? value : value.toString();
    return text.length <= 1200 ? text : '${text.substring(0, 1200)}...';
  }
}
