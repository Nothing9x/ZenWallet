import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/wallet.dart';
import '../models/network.dart';
import '../models/token.dart';
import '../services/wallet_service.dart';
import '../services/blockchain_service.dart';

// =============================================
// BACKUP STATUS PROVIDER - Trust Wallet style
// =============================================
final backupStatusProvider = StateNotifierProvider<BackupStatusNotifier, bool>((ref) {
  return BackupStatusNotifier();
});

class BackupStatusNotifier extends StateNotifier<bool> {
  BackupStatusNotifier() : super(false) {
    _loadStatus();
  }

  static const _key = 'wallet_backed_up';

  Future<void> _loadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> setBackedUp(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    state = value;
  }
}

// =============================================
// CURRENT WALLET PROVIDER
// =============================================
final currentWalletProvider = AsyncNotifierProvider<WalletNotifier, Wallet?>(() {
  return WalletNotifier();
});

class WalletNotifier extends AsyncNotifier<Wallet?> {
  final WalletService _walletService = WalletService();

  @override
  Future<Wallet?> build() async {
    return await _walletService.getCurrentWallet();
  }

  /// Quick create wallet - Trust Wallet style (no seed phrase shown)
  Future<void> createWalletQuick() async {
    state = const AsyncValue.loading();
    
    try {
      final wallet = await _walletService.createWallet();
      
      // Mark as NOT backed up - will show reminder banner
      await ref.read(backupStatusProvider.notifier).setBackedUp(false);
      
      state = AsyncValue.data(wallet);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Create wallet with seed phrase verification (old flow)
  Future<String> createWalletWithSeed() async {
    final mnemonic = _walletService.generateMnemonic();
    return mnemonic;
  }

  /// Confirm wallet creation after seed phrase backup
  Future<void> confirmWalletCreation(String mnemonic) async {
    state = const AsyncValue.loading();
    
    try {
      final wallet = await _walletService.importFromMnemonic(mnemonic);
      
      // Mark as backed up since user saw the seed
      await ref.read(backupStatusProvider.notifier).setBackedUp(true);
      
      state = AsyncValue.data(wallet);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Import wallet from mnemonic
  Future<void> importFromMnemonic(String mnemonic) async {
    state = const AsyncValue.loading();
    
    try {
      final wallet = await _walletService.importFromMnemonic(mnemonic);
      
      // Mark as backed up since user has the seed
      await ref.read(backupStatusProvider.notifier).setBackedUp(true);
      
      state = AsyncValue.data(wallet);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Import wallet from private key
  Future<void> importFromPrivateKey(String privateKey) async {
    state = const AsyncValue.loading();
    
    try {
      final wallet = await _walletService.importFromPrivateKey(privateKey);
      
      // Mark as backed up - user should have their key saved
      await ref.read(backupStatusProvider.notifier).setBackedUp(true);
      
      state = AsyncValue.data(wallet);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Delete wallet
  Future<void> deleteWallet() async {
    await _walletService.deleteWallet();
    await ref.read(backupStatusProvider.notifier).setBackedUp(false);
    state = const AsyncValue.data(null);
  }

  /// Refresh wallet
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _walletService.getCurrentWallet());
  }
}

// =============================================
// NETWORK PROVIDERS
// =============================================
final selectedNetworkProvider = StateProvider<Network>((ref) {
  return Network.ethereum;
});

final allNetworksProvider = Provider<List<Network>>((ref) {
  return Network.allNetworks;
});

// =============================================
// BALANCE PROVIDER
// =============================================
final nativeBalanceProvider = FutureProvider.autoDispose<TokenBalance>((ref) async {
  final wallet = await ref.watch(currentWalletProvider.future);
  final network = ref.watch(selectedNetworkProvider);
  
  if (wallet == null) {
    throw Exception('No wallet found');
  }

  final blockchainService = BlockchainService();
  final balance = await blockchainService.getNativeBalance(wallet.address, network);

  return TokenBalance(
    token: Token.getNativeToken(network.id),
    balance: balance,
  );
});