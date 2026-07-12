# Threading Guide

Nexio keeps developer code simple while moving heavy parsing work away from the
main isolate when needed.

Global threshold:

```dart
Nexio.initialize(
  environments: environments,
  initialEnvironment: 'production',
  defaultThreadMode: ThreadMode.auto,
  parseThresholdKb: 64,
);
```

Per-request override:

```dart
await Nexio.get<List<Item>>(
  '/large-feed',
  threadMode: ThreadMode.background,
  isolateParser: parseItemsInIsolate,
);
```

`ThreadMode.auto` parses small payloads on the main isolate and large JSON
payloads with Flutter's `compute`. Nexio also uses isolate-backed cache cleanup
so expired disk files do not block the request path.

For ordinary `parser` callbacks, Nexio offloads large JSON decoding and then
runs model mapping on the main isolate. This is the safest default because a
closure can capture objects that Dart cannot send between isolates.

Use `isolateParser` when model construction is also expensive:

```dart
List<Item> parseItemsInIsolate(String source) {
  final decoded = jsonDecode(source) as List<Object?>;
  return decoded
      .map((item) => Item.fromJson(
            Map<String, Object?>.from(item! as Map),
          ))
      .toList();
}

final response = await Nexio.get<List<Item>>(
  '/large-feed',
  threadMode: ThreadMode.auto,
  parseThresholdKb: 32,
  isolateParser: parseItemsInIsolate,
);
```

The isolate parser must be top-level or static. It receives serialized,
decrypted response data and should perform both decoding and model construction.
Its result must be isolate-sendable. Do not provide `parser` and
`isolateParser` together.

## Why requests still use `await`

`await` is not the opposite of isolates. `await` means "wait for this Future and
resume this function later." While the Future is pending, Flutter can continue
rendering frames.

Dio network calls are asynchronous I/O. They should be awaited so your code gets
the response, but they do not block the UI thread like synchronous CPU work.

Isolates are used for CPU-heavy work. In Nexio that means large built-in JSON
decoding, explicit full-response model parsing, and expired disk cache cleanup.
These operations also return Futures, so app code still writes `await`.

Use this mental model:

```dart
final response = await Nexio.get<List<User>>(
  '/large-users',
  threadMode: ThreadMode.background,
);
```

The network wait is async I/O. The large JSON decode can run away from the main
isolate. Your function still awaits the final typed response.

## Why Nexio does not move every Dio call into an isolate

Dio uses non-blocking sockets. Moving every HTTP request to a long-lived isolate
adds serialization, send-port coordination, plugin messenger setup, duplicated
state, and more difficult cancellation without making the network itself faster.

Nexio keeps stable Dio clients and their socket pools in the normal async I/O
runtime. It moves work only when CPU cost justifies it:

- large built-in JSON decoding;
- full decoding and model construction through `isolateParser`;
- disk-cache cleanup.

This keeps interceptors, cancellation tokens, Chucker, uploads, downloads, and
custom adapters predictable while protecting Flutter frame rendering from large
decode work.

Use regular parsers for small and medium payloads. Use an isolate parser only
after profiling shows decoding or model construction affects frame time; isolate
startup and data copying have a cost, which is why `ThreadMode.auto` has a
configurable threshold.
