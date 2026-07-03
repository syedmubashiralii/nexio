/// Centralized encryption secrets used by Nexio's built-in ciphers.
class EncryptionConfig {
  /// Creates encryption configuration for AES-CBC and AES-GCM.
  ///
  /// Parameters:
  /// - [aesCbcKey] is the AES-CBC key. It may be UTF-8 text or base64 and must
  ///   decode to 16, 24, or 32 bytes. Defaults to `null`, which disables AES-CBC.
  /// - [aesCbcIv] is the AES-CBC initialization vector. It may be UTF-8 text or
  ///   base64 and must decode to 16 bytes. Defaults to `null`.
  /// - [aesGcmKey] is the AES-GCM key. It may be UTF-8 text or base64 and must
  ///   decode to 16, 24, or 32 bytes. Defaults to `null`, which disables AES-GCM.
  const EncryptionConfig({
    this.aesCbcKey,
    this.aesCbcIv,
    this.aesGcmKey,
  });

  /// Creates encryption configuration from base64 encoded secrets.
  ///
  /// Parameters:
  /// - [aesCbcKeyBase64] is the optional base64 AES-CBC key.
  /// - [aesCbcIvBase64] is the optional base64 AES-CBC IV.
  /// - [aesGcmKeyBase64] is the optional base64 AES-GCM key.
  factory EncryptionConfig.fromBase64({
    String? aesCbcKeyBase64,
    String? aesCbcIvBase64,
    String? aesGcmKeyBase64,
  }) {
    return EncryptionConfig(
      aesCbcKey: aesCbcKeyBase64,
      aesCbcIv: aesCbcIvBase64,
      aesGcmKey: aesGcmKeyBase64,
    );
  }

  /// AES-CBC key as UTF-8 text or base64.
  final String? aesCbcKey;

  /// AES-CBC initialization vector as UTF-8 text or base64.
  final String? aesCbcIv;

  /// AES-GCM key as UTF-8 text or base64.
  final String? aesGcmKey;
}
