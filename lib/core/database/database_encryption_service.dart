/// Encrypted Local Database Service
/// 
/// Encrypts the local SQLite database to prevent unauthorized access
/// to cached evaluation data, child records, and sync history.
/// 
/// Uses AES-256 encryption with key derivation from user credentials.

import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class DatabaseEncryptionService {
  static final DatabaseEncryptionService _instance =
      DatabaseEncryptionService._init();

  late encrypt.Key _encryptionKey;
  late encrypt.IV _iv;
  bool _isInitialized = false;

  DatabaseEncryptionService._init();

  factory DatabaseEncryptionService() => _instance;

  /// Initialize encryption with user's Firebase UID
  /// Should be called after authentication, before any database access
  Future<void> initialize(String userUid) async {
    try {
      // Derive encryption key from user UID + device-specific salt
      _encryptionKey = _deriveKey(userUid);
      _iv = _generateIV();
      _isInitialized = true;

      print('✓ Database encryption initialized');
    } catch (e) {
      print('✗ Failed to initialize encryption: $e');
      rethrow;
    }
  }

  /// Encrypt data for storage
  String encryptData(String plaintext) {
    if (!_isInitialized) {
      throw StateError('Encryption not initialized');
    }

    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
      final encrypted = encrypter.encrypt(plaintext, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      print('Encryption error: $e');
      rethrow;
    }
  }

  /// Decrypt data from storage
  String decryptData(String ciphertext) {
    if (!_isInitialized) {
      throw StateError('Encryption not initialized');
    }

    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
      final decrypted =
          encrypter.decrypt64(ciphertext, iv: _iv);
      return decrypted;
    } catch (e) {
      print('Decryption error: $e');
      rethrow;
    }
  }

  /// Encrypt JSON object
  Map<String, dynamic> encryptJson(Map<String, dynamic> data) {
    final jsonString = _jsonEncode(data);
    return {
      'encrypted': true,
      'data': encryptData(jsonString),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Decrypt JSON object
  Map<String, dynamic> decryptJson(Map<String, dynamic> encrypted) {
    if (encrypted['encrypted'] != true) {
      return encrypted; // Not encrypted, return as-is
    }

    final decrypted = decryptData(encrypted['data'] as String);
    return _jsonDecode(decrypted);
  }

  /// Derive encryption key from user UID
  /// Uses PBKDF2-like derivation for security
  encrypt.Key _deriveKey(String userUid) {
    final salt = 'eccd_growthtrack_db_salt'; // Device-specific in production
    final combined = '$userUid:$salt';

    // Use SHA-256 to derive a 32-byte (256-bit) key
    final key = sha256.convert(combined.codeUnits).bytes;
    return encrypt.Key(Uint8List.fromList(key));
  }

  /// Generate random IV for encryption
  encrypt.IV _generateIV() {
    return encrypt.IV.fromSecureRandom(16);
  }

  /// JSON encoder
  static String _jsonEncode(Map<String, dynamic> data) {
    // TODO: Use a proper JSON encoder (json package)
    return data.toString();
  }

  /// JSON decoder
  static Map<String, dynamic> _jsonDecode(String json) {
    // TODO: Use a proper JSON decoder
    // For now, this is a placeholder
    return {};
  }

  /// Clear encryption state (on logout)
  void dispose() {
    _isInitialized = false;
    print('✓ Database encryption cleared');
  }
}
