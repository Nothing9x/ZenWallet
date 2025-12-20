import 'package:equatable/equatable.dart';

class Network extends Equatable {
  final String id;
  final String name;
  final String symbol;
  final int chainId;
  final String rpcUrl;
  final String explorerUrl;
  final String iconPath;
  final int decimals;
  final bool isTestnet;

  const Network({
    required this.id,
    required this.name,
    required this.symbol,
    required this.chainId,
    required this.rpcUrl,
    required this.explorerUrl,
    required this.iconPath,
    this.decimals = 18,
    this.isTestnet = false,
  });

  String get explorerTxUrl => '$explorerUrl/tx';
  String get explorerAddressUrl => '$explorerUrl/address';

  @override
  List<Object?> get props => [id, chainId];

  // Predefined networks
  static const ethereum = Network(
    id: 'ethereum',
    name: 'Ethereum',
    symbol: 'ETH',
    chainId: 1,
    rpcUrl: 'https://eth.llamarpc.com',
    explorerUrl: 'https://etherscan.io',
    iconPath: 'assets/icons/eth.png',
  );

  static const bsc = Network(
    id: 'bsc',
    name: 'BNB Smart Chain',
    symbol: 'BNB',
    chainId: 56,
    rpcUrl: 'https://bsc-dataseed.binance.org',
    explorerUrl: 'https://bscscan.com',
    iconPath: 'assets/icons/bnb.png',
  );

  static const polygon = Network(
    id: 'polygon',
    name: 'Polygon',
    symbol: 'MATIC',
    chainId: 137,
    rpcUrl: 'https://polygon-rpc.com',
    explorerUrl: 'https://polygonscan.com',
    iconPath: 'assets/icons/matic.png',
  );

  static const arbitrum = Network(
    id: 'arbitrum',
    name: 'Arbitrum One',
    symbol: 'ETH',
    chainId: 42161,
    rpcUrl: 'https://arb1.arbitrum.io/rpc',
    explorerUrl: 'https://arbiscan.io',
    iconPath: 'assets/icons/arb.png',
  );

  static const optimism = Network(
    id: 'optimism',
    name: 'Optimism',
    symbol: 'ETH',
    chainId: 10,
    rpcUrl: 'https://mainnet.optimism.io',
    explorerUrl: 'https://optimistic.etherscan.io',
    iconPath: 'assets/icons/op.png',
  );

  static const avalanche = Network(
    id: 'avalanche',
    name: 'Avalanche C-Chain',
    symbol: 'AVAX',
    chainId: 43114,
    rpcUrl: 'https://api.avax.network/ext/bc/C/rpc',
    explorerUrl: 'https://snowtrace.io',
    iconPath: 'assets/icons/avax.png',
  );

  // List of all supported networks
  static const List<Network> allNetworks = [
    ethereum,
    bsc,
    polygon,
    arbitrum,
    optimism,
    avalanche,
  ];

  static Network? fromChainId(int chainId) {
    try {
      return allNetworks.firstWhere((n) => n.chainId == chainId);
    } catch (_) {
      return null;
    }
  }

  static Network? fromId(String id) {
    try {
      return allNetworks.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }
}
