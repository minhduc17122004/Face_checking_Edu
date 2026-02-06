import 'package:pointycastle/export.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/services.dart' show rootBundle, Uint8List;
import 'dart:convert';
import 'dart:typed_data';

class RSAUtil {
  final RSAPrivateKey privateKey;

  RSAUtil._(this.privateKey);

  // Load private key from asset
  static Future<RSAUtil> fromAsset(String path) async {
    final pem = await rootBundle.loadString(path);

    final cleanPem =
        pem.replaceAll('\r\n', '\n').trim().split('\n').where((line) => line.isNotEmpty).join('\n');

    if (!cleanPem.startsWith('-----BEGIN') || !cleanPem.contains('-----END')) {
      throw Exception('Invalid PEM format: Missing headers');
    }

    try {
      final parser = RSAKeyParser();
      final key = parser.parse(cleanPem);

      if (key is! RSAPrivateKey) {
        throw Exception('Expected RSAPrivateKey, got ${key.runtimeType}');
      }

      // Print key information
      print('=== Private Key Info ===');
      print('Modulus bit length: ${key.modulus!.bitLength} bits');
      print('Key size in bytes: ${(key.modulus!.bitLength + 7) ~/ 8} bytes');
      print('This key can decrypt blocks of: ${(key.modulus!.bitLength + 7) ~/ 8} bytes');

      return RSAUtil._(key);
    } catch (e) {
      throw Exception('PEM parsing failed: $e');
    }
  }

  // Enhanced decrypt with better error handling and debugging
  String decryptFromBase64(String base64HybridCipher) {
    try {
      print('=== Starting Decryption ===');
      print('Input length: ${base64HybridCipher.length}');

      // Decode base64 to bytes
      final decodedBytes = base64Decode(base64HybridCipher);
      print('Decoded bytes length: ${decodedBytes.length}');

      // Convert bytes to String
      final payload = utf8.decode(decodedBytes);
      print('Payload: ${payload.substring(0, payload.length > 100 ? 100 : payload.length)}...');

      // Split by delimiter
      final parts = payload.split(':');
      if (parts.length != 2) {
        throw FormatException('Invalid format: expected 2 parts (RSA:AES), got ${parts.length}');
      }

      final rsaEncryptedB64 = parts[0];
      final aesCiphertextB64 = parts[1];

      print('RSA part length: ${rsaEncryptedB64.length}');
      print('AES part length: ${aesCiphertextB64.length}');

      // Validate base64 strings
      if (rsaEncryptedB64.isEmpty || aesCiphertextB64.isEmpty) {
        throw FormatException('Empty RSA or AES component');
      }

      // Decode RSA encrypted data
      final encryptedKeyIv = base64Decode(rsaEncryptedB64);
      print('Encrypted Key+IV length: ${encryptedKeyIv.length} bytes');
      print('Private key modulus size: ${privateKey.modulus!.bitLength} bits');

      // Expected encrypted block size should match key size
      final expectedSize = (privateKey.modulus!.bitLength + 7) ~/ 8;
      print('Expected RSA block size: $expectedSize bytes');

      if (encryptedKeyIv.length != expectedSize) {
        print('');
        print('⚠️  KEY MISMATCH DETECTED ⚠️');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('The data was encrypted with a DIFFERENT key!');
        print('');
        print('Encrypted block size: ${encryptedKeyIv.length} bytes');
        print('Your private key size: $expectedSize bytes');
        print('');
        print('This means:');
        if (encryptedKeyIv.length == 256) {
          print('  → Data was encrypted with a 2048-bit (256 byte) RSA key');
        } else if (encryptedKeyIv.length == 512) {
          print('  → Data was encrypted with a 4096-bit (512 byte) RSA key');
        } else {
          print('  → Data was encrypted with a ${encryptedKeyIv.length * 8}-bit RSA key');
        }

        if (expectedSize == 384) {
          print('  → Your key is 3072-bit (384 byte)');
        } else if (expectedSize == 256) {
          print('  → Your key is 2048-bit (256 byte)');
        } else if (expectedSize == 512) {
          print('  → Your key is 4096-bit (512 byte)');
        } else {
          print('  → Your key is ${expectedSize * 8}-bit');
        }
        print('');
        print('SOLUTION: Use the private key that matches');
        print('the public key used for encryption.');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        throw StateError(
            'RSA key mismatch: encrypted with ${encryptedKeyIv.length}-byte key, but your private key is $expectedSize bytes. You need the matching private key.');
      }

      // Try PKCS1 padding first (most common)
      Uint8List decryptedKeyIv;
      try {
        print('Attempting PKCS#1 v1.5 padding...');
        final rsaEngine = PKCS1Encoding(RSAEngine())
          ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
        decryptedKeyIv = rsaEngine.process(Uint8List.fromList(encryptedKeyIv));
        print('PKCS#1 decryption successful');
      } catch (e) {
        print('PKCS#1 failed: $e');
        // Try OAEP padding as fallback
        try {
          print('Attempting OAEP padding...');
          final rsaEngine = OAEPEncoding(RSAEngine())
            ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
          decryptedKeyIv = rsaEngine.process(Uint8List.fromList(encryptedKeyIv));
          print('OAEP decryption successful');
        } catch (e2) {
          print('OAEP also failed: $e2');
          throw Exception(
              'RSA decryption failed with both PKCS#1 and OAEP padding. Original error: $e');
        }
      }

      print('Decrypted Key+IV length: ${decryptedKeyIv.length} bytes');

      // Decode decrypted key+IV
      String keyIvHex;
      try {
        keyIvHex = utf8.decode(decryptedKeyIv);
        print('Key+IV hex length: ${keyIvHex.length} chars');
      } catch (e) {
        // If UTF-8 decode fails, data might be raw bytes
        print('UTF-8 decode failed, trying direct hex conversion');
        keyIvHex = decryptedKeyIv.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
        print('Converted to hex: ${keyIvHex.length} chars');
      }

      // Expecting 64 chars (32 bytes) for AES-256 key + 32 chars (16 bytes) for IV = 96 chars
      if (keyIvHex.length < 96) {
        throw StateError(
            'Key+IV too short: ${keyIvHex.length} chars, expected at least 96 (64 for key + 32 for IV)');
      }

      // Extract AES key (32 bytes = 64 hex chars) and IV (16 bytes = 32 hex chars)
      final aesKeyHex = keyIvHex.substring(0, 64);
      final ivHex = keyIvHex.substring(64, 96);

      print('AES Key (hex): ${aesKeyHex.substring(0, 16)}...');
      print('IV (hex): ${ivHex.substring(0, 16)}...');

      // Convert hex strings to bytes
      final aesKeyBytes = _hexToBytes(aesKeyHex);
      final ivBytes = _hexToBytes(ivHex);

      print('AES Key bytes: ${aesKeyBytes.length}');
      print('IV bytes: ${ivBytes.length}');

      // AES Decryption
      final aesKey = Key(aesKeyBytes);
      final iv = IV(ivBytes);
      final aes = Encrypter(AES(aesKey, mode: AESMode.cbc, padding: 'PKCS7'));

      final decrypted = aes.decrypt(Encrypted.fromBase64(aesCiphertextB64), iv: iv);
      print('=== Decryption Successful ===');
      return decrypted;
    } catch (e, stackTrace) {
      print('=== Decryption Failed ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Decryption failed: $e');
    }
  }

  // Helper method to convert hex string to bytes
  Uint8List _hexToBytes(String hex) {
    if (hex.length % 2 != 0) {
      throw FormatException('Hex string must have even length');
    }
    return Uint8List.fromList(
      List<int>.generate(
        hex.length ~/ 2,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );
  }
}
