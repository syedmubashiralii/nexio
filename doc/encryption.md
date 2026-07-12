# Encryption Guide

Nexio supports `EncryptionMode.none`, `EncryptionMode.aesCbc`, and
`EncryptionMode.aesGcm`.

Configure keys once:

```dart
Nexio.initialize(
  environments: environments,
  initialEnvironment: 'production',
  encryptionConfig: const EncryptionConfig(
    aesCbcKey: '12345678901234567890123456789012',
    aesCbcIv: '1234567890123456',
    aesGcmKey: '12345678901234567890123456789012',
  ),
);
```

The literal values above demonstrate valid byte lengths only. Never commit
production secrets to source code. Provision and rotate them through an
app-owned secure process.

Encrypt one request:

```dart
await Nexio.post<Map<String, Object?>>(
  '/payment',
  data: {'amount': 100},
  encryptionMode: EncryptionMode.aesGcm,
);
```

Built-in encryption wraps payloads in a JSON-safe envelope containing mode,
payload, and metadata. If your backend uses a different envelope, implement a
custom `NexioCipher` and register it:

```dart
Nexio.registerCipher(MyEnterpriseCipher());
```

`NexioCipher` customizes the algorithm inside Nexio's envelope. If an existing
backend returns raw encrypted strings, uses a different envelope, or delegates
crypto to an Android/iOS platform channel, implement `NexioEncryptionAdapter`:

```dart
class PlatformGcmAdapter implements NexioEncryptionAdapter {
  const PlatformGcmAdapter(this.channel);

  final MethodChannel channel;

  @override
  EncryptionMode get mode => EncryptionMode.aesGcm;

  @override
  Future<Object?> encryptRequest(Object? payload) async {
    return channel.invokeMethod<String>(
      'encrypt',
      {'data': jsonEncode(payload)},
    );
  }

  @override
  Future<Object?> decryptResponse(Object? payload) async {
    final plainText = await channel.invokeMethod<String>(
      'decrypt',
      {'data': payload},
    );
    return jsonDecode(plainText!);
  }
}

Nexio.registerEncryptionAdapter(
  PlatformGcmAdapter(const MethodChannel('app.crypto')),
);
```

The adapter still runs inside Nexio's encryption interceptor, so callers only
select `encryptionMode`. Platform-channel adapters run on the normal Flutter
isolate; do not call them from `isolateParser`.

Multipart `FormData` is not encrypted by the built-in ciphers. Encrypt files
before upload or provide a custom cipher that matches your backend contract.

Prefer AES-GCM for new contracts because it authenticates ciphertext. The
built-in CBC mode uses the configured IV and does not add a MAC; use it only
when required by a reviewed legacy backend contract. Payload encryption always
complements HTTPS and never replaces it. See the [security guide](security.md).
