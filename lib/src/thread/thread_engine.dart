import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/environment.dart';

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
    final shouldUseBackground = switch (threadMode) {
      ThreadMode.main => false,
      ThreadMode.background => true,
      ThreadMode.auto => utf8.encode(source).length >= thresholdKb * 1024,
    };

    if (!shouldUseBackground) {
      return jsonDecode(source);
    }
    return compute(_decodeJsonInBackground, source);
  }
}

Object? _decodeJsonInBackground(String source) => jsonDecode(source);
