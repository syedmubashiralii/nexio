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

Multipart `FormData` is not encrypted by the built-in ciphers. Encrypt files
before upload or provide a custom cipher that matches your backend contract.

Prefer AES-GCM for new contracts because it authenticates ciphertext. The
built-in CBC mode uses the configured IV and does not add a MAC; use it only
when required by a reviewed legacy backend contract. Payload encryption always
complements HTTPS and never replaces it. See the [security guide](security.md).
