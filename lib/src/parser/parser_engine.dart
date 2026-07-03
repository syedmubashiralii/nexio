import 'dart:convert';

import 'package:xml/xml.dart';

import '../config/environment.dart';
import '../thread/thread_engine.dart';
import 'nexio_parser.dart';

/// Parses decrypted response bodies into typed values.
class NexioParserEngine {
  /// Creates a parser engine.
  ///
  /// Parameters:
  /// - [registry] stores app-level model parsers.
  /// - [threadEngine] runs built-in parsing work.
  NexioParserEngine({
    required this.registry,
    required this.threadEngine,
  });

  /// Registered typed parsers.
  final NexioParserRegistry registry;

  /// Thread engine for JSON parsing.
  final NexioThreadEngine threadEngine;

  /// Parses [input] into [T].
  ///
  /// Parameters:
  /// - [input] is the decrypted response body.
  /// - [parser] is a per-request parser override.
  /// - [threadMode] controls built-in parsing placement.
  /// - [thresholdKb] controls automatic background parsing.
  Future<T> parse<T>(
    Object? input, {
    NexioParser<T>? parser,
    required ThreadMode threadMode,
    required int thresholdKb,
  }) async {
    final decoded = await _decodeIfJson(
      input,
      threadMode: threadMode,
      thresholdKb: thresholdKb,
    );

    if (parser != null) {
      return parser(decoded);
    }

    final registered = registry.parserFor<T>();
    if (registered != null) {
      return registered(decoded);
    }

    if (T == String) {
      return _asString(decoded) as T;
    }
    if (_expectsBytes<T>()) {
      return _asBytes(decoded) as T;
    }
    if (T == XmlDocument) {
      return XmlDocument.parse(_asString(decoded)) as T;
    }
    if (decoded is T) {
      return decoded;
    }
    return decoded as T;
  }

  Future<Object?> _decodeIfJson(
    Object? input, {
    required ThreadMode threadMode,
    required int thresholdKb,
  }) async {
    if (input is! String || !_looksLikeJson(input)) {
      return input;
    }
    return threadEngine.decodeJson(
      input,
      threadMode: threadMode,
      thresholdKb: thresholdKb,
    );
  }

  bool _looksLikeJson(String input) {
    final trimmed = input.trimLeft();
    return trimmed.startsWith('{') || trimmed.startsWith('[');
  }

  String _asString(Object? input) {
    if (input == null) {
      return '';
    }
    if (input is String) {
      return input;
    }
    if (input is List<int>) {
      return utf8.decode(input);
    }
    return jsonEncode(input);
  }

  List<int> _asBytes(Object? input) {
    if (input == null) {
      return <int>[];
    }
    if (input is List<int>) {
      return input;
    }
    if (input is String) {
      return utf8.encode(input);
    }
    return utf8.encode(jsonEncode(input));
  }
}

bool _expectsBytes<T>() => <T>[] is List<List<int>>;
