/// Converts a decoded response body into a typed value.
///
/// The [input] value is already decrypted and decoded from raw text when
/// possible. Parsers may return synchronously or asynchronously.
typedef NexioParser<T> = Future<T> Function(Object? input);

/// Registry for app-level typed response parsers.
class NexioParserRegistry {
  final Map<Type, NexioParser<Object?>> _parsers =
      <Type, NexioParser<Object?>>{};

  /// Registers [parser] for the generic type [T].
  ///
  /// Parameters:
  /// - [parser] converts decrypted and decoded response data into [T].
  ///   Register one parser per model or collection type.
  void register<T>(NexioParser<T> parser) {
    _parsers[T] = (Object? input) async => parser(input);
  }

  /// Returns a parser for [T], or `null` when no parser has been registered.
  NexioParser<T>? parserFor<T>() {
    final parser = _parsers[T];
    if (parser == null) {
      return null;
    }
    return (Object? input) async => parser(input) as T;
  }

  /// Removes every registered parser.
  void clear() {
    _parsers.clear();
  }
}
