import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_theme.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  static const _pinKey = 'wallet_pin';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Mnemonic operations
  Future<void> saveMnemonic(String mnemonic) async {
    await _storage.write(
      key: AppConstants.walletMnemonicKey,
      value: mnemonic,
    );
  }

  Future<String?> getMnemonic() async {
    return await _storage.read(key: AppConstants.walletMnemonicKey);
  }

  Future<void> deleteMnemonic() async {
    await _storage.delete(key: AppConstants.walletMnemonicKey);
  }

  // Private key operations
  Future<void> savePrivateKey(String privateKey) async {
    await _storage.write(
      key: AppConstants.walletPrivateKeyKey,
      value: privateKey,
    );
  }

  Future<String?> getPrivateKey() async {
    return await _storage.read(key: AppConstants.walletPrivateKeyKey);
  }

  Future<void> deletePrivateKey() async {
    await _storage.delete(key: AppConstants.walletPrivateKeyKey);
  }

  // Address operations
  Future<void> saveAddress(String address) async {
    await _storage.write(
      key: AppConstants.walletAddressKey,
      value: address,
    );
  }

  Future<String?> getAddress() async {
    return await _storage.read(key: AppConstants.walletAddressKey);
  }

  // Check if wallet exists
  Future<bool> hasWallet() async {
    final mnemonic = await getMnemonic();
    final privateKey = await getPrivateKey();
    return mnemonic != null || privateKey != null;
  }

  // Delete all wallet data
  Future<void> deleteWallet() async {
    await _storage.delete(key: AppConstants.walletMnemonicKey);
    await _storage.delete(key: AppConstants.walletPrivateKeyKey);
    await _storage.delete(key: AppConstants.walletAddressKey);
  }

  // Delete all data
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  // Generic key-value operations
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  Future<Map<String, String>> readAll() async {
    return await _storage.readAll();
  }

  // PIN operations
  Future<void> savePIN(String pin) async {
    try {
      debugPrint('💾 SecureStorage: Saving PIN (length=${pin.length})');
      await _storage.write(key: _pinKey, value: pin);
      // Ensure write is complete
      await Future.delayed(const Duration(milliseconds: 200));
      debugPrint('✅ SecureStorage: PIN saved successfully');
    } catch (e) {
      debugPrint('❌ SecureStorage: Error saving PIN: $e');
      rethrow;
    }
  }

  Future<String?> getPIN() async {
    try {
      debugPrint('📖 SecureStorage: Reading PIN');
      final pin = await _storage.read(key: _pinKey);
      debugPrint('📖 SecureStorage: PIN found = ${pin != null}');
      return pin;
    } catch (e) {
      debugPrint('❌ SecureStorage: Error reading PIN: $e');
      return null;
    }
  }

  Future<bool> hasPIN() async {
    final pin = await getPIN();
    return pin != null && pin.isNotEmpty;
  }

  Future<bool> verifyPIN(String pin) async {
    try {
      final storedPin = await getPIN();
      return storedPin == pin;
    } catch (e) {
      debugPrint('❌ SecureStorage: Error verifying PIN: $e');
      return false;
    }
  }

  Future<void> deletePIN() async {
    try {
      await _storage.delete(key: _pinKey);
      debugPrint('✅ SecureStorage: PIN deleted');
    } catch (e) {
      debugPrint('❌ SecureStorage: Error deleting PIN: $e');
    }
  }
}
