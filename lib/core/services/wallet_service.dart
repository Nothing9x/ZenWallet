import 'dart:typed_data';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'package:hex/hex.dart';
import 'package:web3dart/web3dart.dart';

import '../models/wallet.dart' as models;
import 'secure_storage_service.dart';

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  final SecureStorageService _secureStorage = SecureStorageService();

  /// Generate a new 12-word mnemonic phrase
  String generateMnemonic() {
    return bip39.generateMnemonic(strength: 128); // 12 words
  }

  /// Validate a mnemonic phrase
  bool validateMnemonic(String mnemonic) {
    return bip39.validateMnemonic(mnemonic);
  }

  /// Derive private key from mnemonic using BIP44 path
  /// Path: m/44'/60'/0'/0/accountIndex
  String derivePrivateKey(String mnemonic, {int accountIndex = 0}) {
    if (!validateMnemonic(mnemonic)) {
      throw ArgumentError('Invalid mnemonic phrase');
    }

    final seed = bip39.mnemonicToSeed(mnemonic);
    final root = bip32.BIP32.fromSeed(seed);
    
    // BIP44 path for Ethereum
    final path = "m/44'/60'/0'/0/$accountIndex";
    final child = root.derivePath(path);
    
    if (child.privateKey == null) {
      throw StateError('Failed to derive private key');
    }

    return HEX.encode(child.privateKey!);
  }

  /// Get Ethereum address from private key
  String getAddressFromPrivateKey(String privateKeyHex) {
    final privateKey = EthPrivateKey.fromHex(privateKeyHex);
    return privateKey.address.hexEip55;
  }

  /// Create a new wallet with generated mnemonic
  Future<models.Wallet> createWallet({String name = 'Main Wallet'}) async {
    final mnemonic = generateMnemonic();
    final privateKey = derivePrivateKey(mnemonic);
    final address = getAddressFromPrivateKey(privateKey);

    // Save to secure storage
    await _secureStorage.saveMnemonic(mnemonic);
    await _secureStorage.savePrivateKey(privateKey);
    await _secureStorage.saveAddress(address);

    return models.Wallet(
      address: address,
      name: name,
      createdAt: DateTime.now(),
      isImported: false,
      accountIndex: 0,
    );
  }

  /// Import wallet from mnemonic phrase
  Future<models.Wallet> importFromMnemonic(
    String mnemonic, {
    String name = 'Imported Wallet',
    int accountIndex = 0,
  }) async {
    if (!validateMnemonic(mnemonic)) {
      throw ArgumentError('Invalid mnemonic phrase');
    }

    final privateKey = derivePrivateKey(mnemonic, accountIndex: accountIndex);
    final address = getAddressFromPrivateKey(privateKey);

    // Save to secure storage
    await _secureStorage.saveMnemonic(mnemonic);
    await _secureStorage.savePrivateKey(privateKey);
    await _secureStorage.saveAddress(address);

    return models.Wallet(
      address: address,
      name: name,
      createdAt: DateTime.now(),
      isImported: true,
      accountIndex: accountIndex,
    );
  }

  /// Import wallet from private key
  Future<models.Wallet> importFromPrivateKey(
    String privateKey, {
    String name = 'Imported Wallet',
  }) async {
    // Validate private key format
    String cleanKey = privateKey.trim();
    if (cleanKey.startsWith('0x')) {
      cleanKey = cleanKey.substring(2);
    }

    if (cleanKey.length != 64) {
      throw ArgumentError('Invalid private key length');
    }

    try {
      final address = getAddressFromPrivateKey(cleanKey);

      // Save to secure storage (no mnemonic for private key import)
      await _secureStorage.savePrivateKey(cleanKey);
      await _secureStorage.saveAddress(address);

      return models.Wallet(
        address: address,
        name: name,
        createdAt: DateTime.now(),
        isImported: true,
        accountIndex: 0,
      );
    } catch (e) {
      throw ArgumentError('Invalid private key');
    }
  }

  /// Get current wallet from storage
  Future<models.Wallet?> getCurrentWallet() async {
    final address = await _secureStorage.getAddress();
    if (address == null) return null;

    return models.Wallet(
      address: address,
      name: 'Main Wallet',
      createdAt: DateTime.now(),
      isImported: false,
      accountIndex: 0,
    );
  }

  /// Get EthPrivateKey for signing transactions
  Future<EthPrivateKey?> getCredentials() async {
    final privateKey = await _secureStorage.getPrivateKey();
    if (privateKey == null) return null;
    return EthPrivateKey.fromHex(privateKey);
  }

  /// Get mnemonic (for backup purposes)
  Future<String?> getMnemonic() async {
    return await _secureStorage.getMnemonic();
  }

  /// Delete wallet
  Future<void> deleteWallet() async {
    await _secureStorage.deleteWallet();
  }

  /// Check if wallet exists
  Future<bool> hasWallet() async {
    return await _secureStorage.hasWallet();
  }

  /// Sign a message
  Future<Uint8List> signMessage(String message) async {
    final credentials = await getCredentials();
    if (credentials == null) {
      throw StateError('No wallet found');
    }
    return credentials.signPersonalMessageToUint8List(
      Uint8List.fromList(message.codeUnits),
    );
  }
}
