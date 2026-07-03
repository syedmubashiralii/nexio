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
  parser: itemListParser,
);
```

`ThreadMode.auto` parses small payloads on the main isolate and large JSON
payloads with Flutter's `compute`. Nexio also uses isolate-backed cache cleanup
so expired disk files do not block the request path.

## Why requests still use `await`

`await` is not the opposite of isolates. `await` means "wait for this Future and
resume this function later." While the Future is pending, Flutter can continue
rendering frames.

Dio network calls are asynchronous I/O. They should be awaited so your code gets
the response, but they do not block the UI thread like synchronous CPU work.

Isolates are used for CPU-heavy work. In Nexio that means large built-in JSON
decoding when `ThreadMode.auto` crosses `parseThresholdKb`, forced background
parsing with `ThreadMode.background`, and expired disk cache cleanup. These
operations also return Futures, so app code still writes `await`.

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
- forced background parsing through `ThreadMode.background`;
- disk-cache cleanup.

This keeps interceptors, cancellation tokens, Chucker, uploads, downloads, and
custom adapters predictable while protecting Flutter frame rendering from large
decode work.

Custom model parsers run after built-in JSON decoding. Keep parsers focused on
mapping decoded data into application types; benchmark expensive custom
transformations separately.
