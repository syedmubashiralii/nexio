import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../config/environment.dart';
import '../parser/nexio_parser.dart';

/// Runs parser work on the main isolate or a background isolate.
class NexioThreadEngine {
  /// Decodes a JSON [source] using [threadMode] and [thresholdKb].
  ///
  /// Parameters:
  /// - [source] is the raw JSON string.
  /// - [threadMode] controls isolate selection.
  /// - [thresholdKb] is used only by [ThreadMode.auto].
  Future<Object?> decodeJson(
    String source, {
    required ThreadMode threadMode,
    required int thresholdKb,
  }) async {
    final shouldUseBackground = _shouldUseBackground(
      source,
      threadMode: threadMode,
      thresholdKb: thresholdKb,
    );

    if (!shouldUseBackground) {
      return jsonDecode(source);
    }
    return compute(_decodeJsonInBackground, source);
  }

  /// Runs a complete serialized-response [parser] using the selected mode.
  ///
  /// Parameters:
  /// - [source] is the serialized decrypted response.
  /// - [parser] is a top-level or static CPU parser.
  /// - [threadMode] controls isolate selection.
  /// - [thresholdKb] is used only by [ThreadMode.auto].
  Future<T> parseSerialized<T>(
    String source,
    NexioIsolateParser<T> parser, {
    required ThreadMode threadMode,
    required int thresholdKb,
  }) async {
    final shouldUseBackground = _shouldUseBackground(
      source,
      threadMode: threadMode,
      thresholdKb: thresholdKb,
    );
    if (!shouldUseBackground) {
      return parser(source);
    }
    return Isolate.run<T>(() => parser(source));
  }

  bool _shouldUseBackground(
    String source, {
    required ThreadMode threadMode,
    required int thresholdKb,
  }) {
    return switch (threadMode) {
      ThreadMode.main => false,
      ThreadMode.background => true,
      ThreadMode.auto => utf8.encode(source).length >= thresholdKb * 1024,
    };
  }
}

Object? _decodeJsonInBackground(String source) => jsonDecode(source);
