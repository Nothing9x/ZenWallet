import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:web3dart/web3dart.dart';
import 'package:hex/hex.dart';

import '../models/wallet.dart' as app_wallet;
import '../../features/wallet_list/wallet_list_screen.dart';

class WalletService {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _mnemonicKeyPrefix = 'wallet_mnemonic_';
  static const _privateKeyPrefix = 'wallet_private_key_';
  static const _walletsListKey = 'wallets_list';
  static const _currentWalletKey = 'current_wallet_address';
  static const _walletNamesKey = 'wallet_names';

  Future<List<WalletInfo>> getAllWallets() async {
    final prefs = await SharedPreferences.getInstance();
    final walletsJson = prefs.getStringList(_walletsListKey) ?? [];
    final namesJson = prefs.getString(_walletNamesKey);
    
    Map<String, String> names = {};
    if (namesJson != null) {
      names = Map<String, String>.from(jsonDecode(namesJson));
    }

    final wallets = <WalletInfo>[];
    for (int i = 0; i < walletsJson.length; i++) {
      final data = jsonDecode(walletsJson[i]);
      final address = data['address'] as String;
      wallets.add(WalletInfo(
        address: address,
        name: names[address] ?? 'Ví ${i + 1}',
        createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
      ));
    }
    return wallets;
  }

  Future<void> _addWalletToList(String address) async {
    final prefs = await SharedPreferences.getInstance();
    final walletsJson = prefs.getStringList(_walletsListKey) ?? [];
    
    final exists = walletsJson.any((w) {
      final data = jsonDecode(w);
      return data['address'] == address;
    });
    
    if (!exists) {
      walletsJson.add(jsonEncode({
        'address': address,
        'createdAt': DateTime.now().toIso8601String(),
      }));
      await prefs.setStringList(_walletsListKey, walletsJson);
      final walletCount = walletsJson.length;
      await renameWallet(address, 'Ví $walletCount');
    }
  }

  Future<void> _removeWalletFromList(String address) async {
    final prefs = await SharedPreferences.getInstance();
    final walletsJson = prefs.getStringList(_walletsListKey) ?? [];
    walletsJson.removeWhere((w) {
      final data = jsonDecode(w);
      return data['address'] == address;
    });
    await prefs.setStringList(_walletsListKey, walletsJson);
  }

  Future<void> renameWallet(String address, String newName) async {
    final prefs = await SharedPreferences.getInstance();
    final namesJson = prefs.getString(_walletNamesKey);
    Map<String, String> names = {};
    if (namesJson != null) {
      names = Map<String, String>.from(jsonDecode(namesJson));
    }
    names[address] = newName;
    await prefs.setString(_walletNamesKey, jsonEncode(names));
  }

  Future<String> getWalletName(String address) async {
    final prefs = await SharedPreferences.getInstance();
    final namesJson = prefs.getString(_walletNamesKey);
    if (namesJson != null) {
      final names = Map<String, String>.from(jsonDecode(namesJson));
      return names[address] ?? 'Ví';
    }
    return 'Ví';
  }

  Future<void> setCurrentWallet(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentWalletKey, address);
  }

  Future<String?> getCurrentWalletAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentWalletKey);
  }

  Future<void> deleteWalletByAddress(String address) async {
    await _secureStorage.delete(key: '$_mnemonicKeyPrefix$address');
    await _secureStorage.delete(key: '$_privateKeyPrefix$address');
    await _removeWalletFromList(address);
    
    final currentAddress = await getCurrentWalletAddress();
    if (currentAddress == address) {
      final wallets = await getAllWallets();
      if (wallets.isNotEmpty) {
        await setCurrentWallet(wallets.first.address);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_currentWalletKey);
      }
    }
  }

  String generateMnemonic() {
    return bip39.generateMnemonic();
  }

  bool validateMnemonic(String mnemonic) {
    return bip39.validateMnemonic(mnemonic);
  }

  Future<app_wallet.Wallet> createWallet() async {
    final mnemonic = generateMnemonic();
    return await importFromMnemonic(mnemonic);
  }

  Future<app_wallet.Wallet> importFromMnemonic(String mnemonic) async {
    if (!validateMnemonic(mnemonic)) {
      throw Exception('Invalid mnemonic phrase');
    }

    final seed = bip39.mnemonicToSeed(mnemonic);
    final privateKey = _derivePrivateKey(seed);
    final credentials = EthPrivateKey.fromHex(privateKey);
    final address = credentials.address.hexEip55;

    await _secureStorage.write(key: '$_mnemonicKeyPrefix$address', value: mnemonic);
    await _secureStorage.write(key: '$_privateKeyPrefix$address', value: privateKey);
    await _addWalletToList(address);
    await setCurrentWallet(address);

    final walletName = await getWalletName(address);
    return app_wallet.Wallet(
      address: address,
      name: walletName,
      createdAt: DateTime.now(),
      isImported: false,
      accountIndex: 0,
    );
  }

  Future<app_wallet.Wallet> importFromPrivateKey(String privateKey) async {
    String cleanKey = privateKey;
    if (cleanKey.startsWith('0x')) {
      cleanKey = cleanKey.substring(2);
    }

    if (cleanKey.length != 64) {
      throw Exception('Invalid private key length');
    }

    final credentials = EthPrivateKey.fromHex(cleanKey);
    final address = credentials.address.hexEip55;

    await _secureStorage.write(key: '$_privateKeyPrefix$address', value: cleanKey);
    await _addWalletToList(address);
    await setCurrentWallet(address);

    final walletName = await getWalletName(address);
    return app_wallet.Wallet(
      address: address,
      name: walletName,
      createdAt: DateTime.now(),
      isImported: true,
      accountIndex: 0,
    );
  }

  Future<app_wallet.Wallet?> getCurrentWallet() async {
    final address = await getCurrentWalletAddress();
    if (address == null) return null;

    final hasPrivateKey = await _secureStorage.read(key: '$_privateKeyPrefix$address');
    if (hasPrivateKey == null) return null;

    final name = await getWalletName(address);
    
    // Get wallet info from list for createdAt
    final wallets = await getAllWallets();
    final walletInfo = wallets.where((w) => w.address == address).firstOrNull;
    
    return app_wallet.Wallet(
      address: address,
      name: name,
      createdAt: walletInfo?.createdAt ?? DateTime.now(),
      isImported: false,
      accountIndex: 0,
    );
  }

  Future<bool> hasWallet() async {
    final wallets = await getAllWallets();
    return wallets.isNotEmpty;
  }

  Future<String?> getMnemonic() async {
    final address = await getCurrentWalletAddress();
    if (address == null) return null;
    return await _secureStorage.read(key: '$_mnemonicKeyPrefix$address');
  }

  Future<String?> getPrivateKey() async {
    final address = await getCurrentWalletAddress();
    if (address == null) return null;
    return await _secureStorage.read(key: '$_privateKeyPrefix$address');
  }

  Future<EthPrivateKey?> getCredentials() async {
    final privateKey = await getPrivateKey();
    if (privateKey == null) return null;
    return EthPrivateKey.fromHex(privateKey);
  }

  Future<void> deleteWallet() async {
    final address = await getCurrentWalletAddress();
    if (address != null) {
      await deleteWalletByAddress(address);
    }
  }

  Future<void> deleteAllWallets() async {
    final wallets = await getAllWallets();
    for (final wallet in wallets) {
      await _secureStorage.delete(key: '$_mnemonicKeyPrefix${wallet.address}');
      await _secureStorage.delete(key: '$_privateKeyPrefix${wallet.address}');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_walletsListKey);
    await prefs.remove(_currentWalletKey);
    await prefs.remove(_walletNamesKey);
  }

  String _derivePrivateKey(List<int> seed) {
    final privateKeyBytes = seed.sublist(0, 32);
    return HEX.encode(privateKeyBytes);
  }
}