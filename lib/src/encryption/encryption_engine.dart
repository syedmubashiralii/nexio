import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:encrypt/encrypt.dart' as enc;

import '../config/encryption_config.dart';
import '../config/environment.dart';
import '../errors/nexio_exception.dart';

/// Pluggable encryption contract used by Nexio.
abstract class NexioCipher {
  /// Encryption mode handled by this cipher.
  EncryptionMode get mode;

  /// Encrypts [plainText] and returns a JSON-safe envelope.
  ///
  /// Parameters:
  /// - [plainText] is the serialized plaintext body.
  Future<Map<String, Object?>> encrypt(String plainText);

  /// Decrypts [envelope] and returns serialized plaintext.
  ///
  /// Parameters:
  /// - [envelope] is the JSON-safe envelope returned by [encrypt].
  Future<String> decrypt(Map<String, Object?> envelope);
}

/// Adapts an encryption mode to an app-specific backend wire contract.
///
/// Use this when the backend or a platform-channel crypto service does not use
/// Nexio's built-in JSON envelope. Registering an adapter replaces built-in
/// request and response transformation for its [mode].
abstract class NexioEncryptionAdapter {
  /// Encryption mode handled by this adapter.
  EncryptionMode get mode;

  /// Converts a serialized app request [payload] to the backend wire format.
  ///
  /// Parameters:
  /// - [payload] is the original request body before Dio sends it.
  Future<Object?> encryptRequest(Object? payload);

  /// Converts a backend [payload] to decrypted JSON, text, or bytes.
  ///
  /// Parameters:
  /// - [payload] is the response body received by Dio.
  Future<Object?> decryptResponse(Object? payload);
}

/// Encrypts request payloads and decrypts response payloads.
class NexioEncryptionEngine {
  /// Creates an encryption engine.
  ///
  /// Parameters:
  /// - [config] supplies secrets for the built-in ciphers.
  NexioEncryptionEngine(EncryptionConfig config) {
    if (config.aesCbcKey != null && config.aesCbcIv != null) {
      registerCipher(_AesCbcCipher(config));
    }
    if (config.aesGcmKey != null) {
      registerCipher(_AesGcmCipher(config));
    }
  }

  final Map<EncryptionMode, NexioCipher> _ciphers =
      <EncryptionMode, NexioCipher>{};
  final Map<EncryptionMode, NexioEncryptionAdapter> _adapters =
      <EncryptionMode, NexioEncryptionAdapter>{};

  /// Registers or replaces a cipher.
  ///
  /// Parameters:
  /// - [cipher] handles one [EncryptionMode].
  void registerCipher(NexioCipher cipher) {
    _ciphers[cipher.mode] = cipher;
  }

  /// Registers or replaces a backend wire-format adapter.
  ///
  /// Parameters:
  /// - [adapter] owns request and response transformation for one mode.
  void registerAdapter(NexioEncryptionAdapter adapter) {
    _adapters[adapter.mode] = adapter;
  }

  /// Encrypts [payload] for [mode].
  ///
  /// Parameters:
  /// - [payload] is the request body before Dio receives it.
  /// - [mode] controls which cipher is used.
  Future<Object?> encryptRequest(Object? payload, EncryptionMode mode) async {
    if (mode == EncryptionMode.none || payload == null) {
      return payload;
    }
    final adapter = _adapters[mode];
    if (adapter != null) {
      return adapter.encryptRequest(payload);
    }
    final cipher = _cipherFor(mode);
    final serialized = _SerializedPayload.from(payload);
    final envelope = await cipher.encrypt(serialized.text);
    envelope['contentType'] = serialized.contentType;
    envelope['nexioEncrypted'] = true;
    envelope['mode'] = mode.name;
    return envelope;
  }

  /// Decrypts [payload] for [mode] when it contains a Nexio envelope.
  ///
  /// Parameters:
  /// - [payload] is the response body returned by Dio.
  /// - [mode] controls which cipher is expected.
  Future<Object?> decryptResponse(Object? payload, EncryptionMode mode) async {
    if (mode == EncryptionMode.none || payload == null) {
      return payload;
    }
    final adapter = _adapters[mode];
    if (adapter != null) {
      return adapter.decryptResponse(payload);
    }
    final envelope = _readEnvelope(payload);
    if (envelope == null) {
      return payload;
    }
    final envelopeMode = envelope['mode']?.toString();
    final selectedMode = EncryptionMode.values.firstWhere(
      (value) => value.name == envelopeMode,
      orElse: () => mode,
    );
    final cipher = _cipherFor(selectedMode);
    final plainText = await cipher.decrypt(envelope);
    return _SerializedPayload.restore(
      envelope['contentType']?.toString() ?? 'json',
      plainText,
    );
  }

  NexioCipher _cipherFor(EncryptionMode mode) {
    final cipher = _ciphers[mode];
    if (cipher == null) {
      throw NexioEncryptionException(
        'No cipher is configured for ${mode.name}.',
      );
    }
    return cipher;
  }

  Map<String, Object?>? _readEnvelope(Object? payload) {
    Object? candidate = payload;
    if (payload is String) {
      try {
        candidate = jsonDecode(payload);
      } catch (_) {
        return null;
      }
    }
    if (candidate is! Map) {
      return null;
    }
    final map = <String, Object?>{
      for (final entry in candidate.entries) entry.key.toString(): entry.value,
    };
    return map['nexioEncrypted'] == true ? map : null;
  }
}

class _AesCbcCipher implements NexioCipher {
  _AesCbcCipher(EncryptionConfig config)
      : _key = _decodeSecret(
          'aesCbcKey',
          config.aesCbcKey,
          const <int>{16, 24, 32},
        ),
        _iv = _decodeSecret('aesCbcIv', config.aesCbcIv, const <int>{16});

  final List<int> _key;
  final List<int> _iv;

  @override
  EncryptionMode get mode => EncryptionMode.aesCbc;

  @override
  Future<Map<String, Object?>> encrypt(String plainText) async {
    final encrypter = enc.Encrypter(
      enc.AES(
        enc.Key(Uint8List.fromList(_key)),
        mode: enc.AESMode.cbc,
      ),
    );
    final encrypted = encrypter.encrypt(
      plainText,
      iv: enc.IV(Uint8List.fromList(_iv)),
    );
    return <String, Object?>{'payload': encrypted.base64};
  }

  @override
  Future<String> decrypt(Map<String, Object?> envelope) async {
    final payload = envelope['payload']?.toString();
    if (payload == null) {
      throw const NexioEncryptionException('AES-CBC payload is missing.');
    }
    final encrypter = enc.Encrypter(
      enc.AES(
        enc.Key(Uint8List.fromList(_key)),
        mode: enc.AESMode.cbc,
      ),
    );
    return encrypter.decrypt64(
      payload,
      iv: enc.IV(Uint8List.fromList(_iv)),
    );
  }
}

class _AesGcmCipher implements NexioCipher {
  _AesGcmCipher(EncryptionConfig config)
      : _key = _decodeSecret(
          'aesGcmKey',
          config.aesGcmKey,
          const <int>{16, 24, 32},
        );

  final List<int> _key;

  @override
  EncryptionMode get mode => EncryptionMode.aesGcm;

  @override
  Future<Map<String, Object?>> encrypt(String plainText) async {
    final algorithm = _gcmForKey(_key);
    final secretBox = await algorithm.encrypt(
      utf8.encode(plainText),
      secretKey: crypto.SecretKey(_key),
    );
    return <String, Object?>{
      'payload': base64Encode(secretBox.cipherText),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
    };
  }

  @override
  Future<String> decrypt(Map<String, Object?> envelope) async {
    final payload = envelope['payload']?.toString();
    final nonce = envelope['nonce']?.toString();
    final mac = envelope['mac']?.toString();
    if (payload == null || nonce == null || mac == null) {
      throw const NexioEncryptionException('AES-GCM envelope is incomplete.');
    }
    final algorithm = _gcmForKey(_key);
    final bytes = await algorithm.decrypt(
      crypto.SecretBox(
        base64Decode(payload),
        nonce: base64Decode(nonce),
        mac: crypto.Mac(base64Decode(mac)),
      ),
      secretKey: crypto.SecretKey(_key),
    );
    return utf8.decode(bytes);
  }
}

class _SerializedPayload {
  const _SerializedPayload(this.contentType, this.text);

  final String contentType;
  final String text;

  factory _SerializedPayload.from(Object payload) {
    if (payload is String) {
      return _SerializedPayload('text', payload);
    }
    if (payload is List<int>) {
      return _SerializedPayload('bytes', base64Encode(payload));
    }
    return _SerializedPayload('json', jsonEncode(payload));
  }

  static Object? restore(String contentType, String text) {
    return switch (contentType) {
      'text' => text,
      'bytes' => base64Decode(text),
      _ => jsonDecode(text),
    };
  }
}

crypto.AesGcm _gcmForKey(List<int> key) {
  return switch (key.length) {
    16 => crypto.AesGcm.with128bits(),
    24 => crypto.AesGcm.with192bits(),
    32 => crypto.AesGcm.with256bits(),
    _ => throw const NexioEncryptionException(
        'AES-GCM key must be 16, 24, or 32 bytes.',
      ),
  };
}

List<int> _decodeSecret(String name, String? value, Set<int> validLengths) {
  if (value == null || value.isEmpty) {
    throw NexioEncryptionException('$name is required.');
  }
  final utf8Bytes = utf8.encode(value);
  if (validLengths.contains(utf8Bytes.length)) {
    return utf8Bytes;
  }
  try {
    final base64Bytes = base64Decode(value);
    if (validLengths.contains(base64Bytes.length)) {
      return base64Bytes;
    }
  } catch (_) {
    // The explicit error below is more useful than a base64 parsing error.
  }
  throw NexioEncryptionException(
    '$name must decode to one of these byte lengths: ${validLengths.join(', ')}.',
  );
}
