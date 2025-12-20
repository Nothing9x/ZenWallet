import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/network.dart';
import '../models/token.dart';
import '../models/wallet.dart';
import '../services/wallet_service.dart';
import '../services/blockchain_service.dart';

// Wallet Service Provider
final walletServiceProvider = Provider<WalletService>((ref) {
  return WalletService();
});

// Blockchain Service Provider
final blockchainServiceProvider = Provider<BlockchainService>((ref) {
  return BlockchainService();
});

// Current Wallet Provider
final currentWalletProvider = StateNotifierProvider<WalletNotifier, AsyncValue<Wallet?>>((ref) {
  return WalletNotifier(ref);
});

class WalletNotifier extends StateNotifier<AsyncValue<Wallet?>> {
  final Ref _ref;
  
  WalletNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    state = const AsyncValue.loading();
    try {
      final wallet = await _ref.read(walletServiceProvider).getCurrentWallet();
      state = AsyncValue.data(wallet);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createWallet() async {
    state = const AsyncValue.loading();
    try {
      final wallet = await _ref.read(walletServiceProvider).createWallet();
      state = AsyncValue.data(wallet);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> importFromMnemonic(String mnemonic) async {
    state = const AsyncValue.loading();
    try {
      final wallet = await _ref.read(walletServiceProvider).importFromMnemonic(mnemonic);
      state = AsyncValue.data(wallet);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> importFromPrivateKey(String privateKey) async {
    state = const AsyncValue.loading();
    try {
      final wallet = await _ref.read(walletServiceProvider).importFromPrivateKey(privateKey);
      state = AsyncValue.data(wallet);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteWallet() async {
    await _ref.read(walletServiceProvider).deleteWallet();
    state = const AsyncValue.data(null);
  }

  void refresh() {
    _loadWallet();
  }
}

// Selected Network Provider
final selectedNetworkProvider = StateProvider<Network>((ref) {
  return Network.ethereum;
});

// All Networks Provider
final allNetworksProvider = Provider<List<Network>>((ref) {
  return Network.allNetworks;
});

// Native Token Balance Provider
final nativeBalanceProvider = FutureProvider.autoDispose<TokenBalance>((ref) async {
  final wallet = ref.watch(currentWalletProvider).valueOrNull;
  final network = ref.watch(selectedNetworkProvider);
  
  if (wallet == null) {
    throw Exception('No wallet found');
  }

  final blockchain = ref.read(blockchainServiceProvider);
  final balance = await blockchain.getNativeBalance(wallet.address, network);
  
  final nativeToken = Token.getNativeToken(network.id);
  
  return TokenBalance(
    token: nativeToken,
    balance: balance,
  );
});

// Gas Price Provider
final gasPriceProvider = FutureProvider.autoDispose<BigInt>((ref) async {
  final network = ref.watch(selectedNetworkProvider);
  final blockchain = ref.read(blockchainServiceProvider);
  return await blockchain.getGasPrice(network);
});

// Transaction Fee Estimate Provider
final transactionFeeProvider = FutureProvider.autoDispose.family<BigInt, TransactionParams>((ref, params) async {
  final network = ref.watch(selectedNetworkProvider);
  final blockchain = ref.read(blockchainServiceProvider);
  final wallet = ref.watch(currentWalletProvider).valueOrNull;
  
  if (wallet == null) {
    throw Exception('No wallet found');
  }

  final gasLimit = await blockchain.estimateGas(
    from: wallet.address,
    to: params.to,
    value: params.value,
    network: network,
  );
  
  final gasPrice = await blockchain.getGasPrice(network);
  
  return gasLimit * gasPrice;
});

// Parameters for transaction fee estimation
class TransactionParams {
  final String to;
  final BigInt value;

  TransactionParams({required this.to, required this.value});
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionParams &&
          runtimeType == other.runtimeType &&
          to == other.to &&
          value == other.value;

  @override
  int get hashCode => to.hashCode ^ value.hashCode;
}

// Send Transaction Provider
final sendTransactionProvider = FutureProvider.autoDispose.family<String, SendTransactionParams>((ref, params) async {
  final network = ref.watch(selectedNetworkProvider);
  final blockchain = ref.read(blockchainServiceProvider);
  
  return await blockchain.sendTransaction(
    to: params.to,
    value: params.value,
    network: network,
    gasLimit: params.gasLimit,
    gasPrice: params.gasPrice,
  );
});

class SendTransactionParams {
  final String to;
  final BigInt value;
  final BigInt? gasLimit;
  final BigInt? gasPrice;

  SendTransactionParams({
    required this.to,
    required this.value,
    this.gasLimit,
    this.gasPrice,
  });
}
