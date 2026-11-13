import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'vault_store.dart';
import 'vault_storage_stub.dart'
    if (dart.library.io) 'vault_storage_io.dart'
    if (dart.library.html) 'vault_storage_web.dart' as storage;

/// AES-256-GCM vault; its encryption key is held in platform secure storage.
class EncryptedVault implements VaultStore {
  EncryptedVault({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(
          // Use the macOS login keychain for local/dev builds; the Data Protection
          // keychain requires a Keychain Sharing entitlement (-34018 otherwise).
          mOptions: MacOsOptions(useDataProtectionKeyChain: false),
        );

  static const _keyName = 'hisabflow_vault_key_v1';
  final FlutterSecureStorage _secureStorage;
  final _cipher = AesGcm.with256bits();

  Future<SecretKey> _key() async {
    var encoded = await _secureStorage.read(key: _keyName);
    if (encoded == null) {
      final random = Random.secure();
      encoded = base64Encode(List<int>.generate(32, (_) => random.nextInt(256)));
      await _secureStorage.write(key: _keyName, value: encoded);
    }
    return SecretKey(base64Decode(encoded));
  }

  Future<void> write(Map<String, Object?> document) async {
    final nonce = _cipher.newNonce();
    final box = await _cipher.encrypt(utf8.encode(jsonEncode(document)), secretKey: await _key(), nonce: nonce);
    await storage.writeEnvelope(jsonEncode({
      'version': 1,
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    }));
  }

  Future<Map<String, dynamic>?> read() async {
    final content = await storage.readEnvelope();
    if (content == null) return null;
    final envelope = jsonDecode(content) as Map<String, dynamic>;
    final clear = await _cipher.decrypt(
      SecretBox(
        base64Decode(envelope['ciphertext'] as String),
        nonce: base64Decode(envelope['nonce'] as String),
        mac: Mac(base64Decode(envelope['mac'] as String)),
      ),
      secretKey: await _key(),
    );
    return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
  }

  Future<void> delete() async {
    await storage.deleteEnvelope();
    await _secureStorage.delete(key: _keyName);
  }
}
