import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Graphe book DRM helpers — mirrors graphe-reader CryptoJS logic:
/// PBKDF2(userId, secret) → unwrap per-user key/iv → AES-256-CBC decrypt file.
class BookDecryptService {
  BookDecryptService._();

  /// Must match backend `USER_KEY_SECRET` / graphe-reader secret.
  static const String userKeySecret = r'L|QJ^"mu<h%g*[N5uRYI|zJ7AZm[;oEa';

  /// Backend falls back to this when `USER_KEY_SECRET` was unset at purchase time.
  static const String legacyServerSecret = 'serverSecret';

  /// Secrets to try, in order (current env + historical fallback).
  static const List<String> candidateSecrets = [
    userKeySecret,
    legacyServerSecret,
  ];

  /// PBKDF2-HMAC-SHA256, 100000 iterations, 32-byte key (CryptoJS / Node).
  static Uint8List deriveUserKey(String userId, [String? secret]) {
    final password = Uint8List.fromList(utf8.encode(userId));
    final salt = Uint8List.fromList(utf8.encode(secret ?? userKeySecret));
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, 100000, 32));
    return derivator.process(password);
  }

  /// Decrypts a hex blob that is `IV(16) || AES-CBC(ciphertext)`.
  /// Returns the plaintext as a hex string (same as CryptoJS `.toString(Hex)`).
  static String decryptWrappedHex(Uint8List userKey, String encryptedHex) {
    final encrypted = _hexToBytes(encryptedHex);
    if (encrypted.length <= 16) {
      throw const BookDecryptException('Encrypted key/IV payload is too short');
    }
    final iv = encrypted.sublist(0, 16);
    final ciphertext = encrypted.sublist(16);
    final plain = _aesCbcDecrypt(userKey, iv, ciphertext);
    return _bytesToHex(plain);
  }

  /// Decrypts an encrypted book file with the unwrapped hex key + IV.
  static Uint8List decryptFile(
    Uint8List encryptedData,
    String hexKey,
    String hexIv,
  ) {
    final key = _hexToBytes(hexKey);
    final iv = _hexToBytes(hexIv);
    if (key.length != 32) {
      throw BookDecryptException('Expected 32-byte AES key, got ${key.length}');
    }
    if (iv.length != 16) {
      throw BookDecryptException('Expected 16-byte IV, got ${iv.length}');
    }
    return _aesCbcDecrypt(key, iv, encryptedData);
  }

  /// Full pipeline: derive user key → unwrap encryption key/IV → decrypt file.
  ///
  /// Tries [secret] if provided; otherwise tries [candidateSecrets] because
  /// some purchased/library rows were wrapped with the backend `"serverSecret"`
  /// fallback when `USER_KEY_SECRET` was not loaded.
  static Uint8List decryptBookBytes({
    required String userId,
    required String encryptionKeyHex,
    required String encryptionIvHex,
    required Uint8List encryptedFileBytes,
    String? secret,
  }) {
    final secrets = secret != null ? [secret] : candidateSecrets;
    Object? lastError;

    for (final candidate in secrets) {
      try {
        final userKey = deriveUserKey(userId, candidate);
        final fileKeyHex = decryptWrappedHex(userKey, encryptionKeyHex);
        final fileIvHex = decryptWrappedHex(userKey, encryptionIvHex);
        return decryptFile(encryptedFileBytes, fileKeyHex, fileIvHex);
      } catch (e) {
        lastError = e;
      }
    }

    throw BookDecryptException(
      'Failed to decrypt book (wrong key or corrupt data): $lastError',
    );
  }

  static Uint8List _aesCbcDecrypt(
    Uint8List key,
    Uint8List iv,
    Uint8List ciphertext,
  ) {
    if (ciphertext.isEmpty || ciphertext.length % 16 != 0) {
      throw BookDecryptException(
        'Ciphertext length must be a multiple of 16 (got ${ciphertext.length})',
      );
    }
    // Explicit impl — avoids registry string factory differences across versions.
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    );
    cipher.init(
      false,
      PaddedBlockCipherParameters(
        ParametersWithIV(KeyParameter(key), iv),
        null,
      ),
    );
    return cipher.process(ciphertext);
  }

  static Uint8List _hexToBytes(String hex) {
    final cleaned = hex.trim().replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty || cleaned.length.isOdd) {
      throw BookDecryptException('Invalid hex string');
    }
    final out = Uint8List(cleaned.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static String _bytesToHex(Uint8List bytes) {
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

class BookDecryptException implements Exception {
  const BookDecryptException(this.message);

  final String message;

  @override
  String toString() => message;
}
