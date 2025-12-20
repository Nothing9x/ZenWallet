import 'package:equatable/equatable.dart';

class Token extends Equatable {
  final String address;
  final String symbol;
  final String name;
  final int decimals;
  final String? iconUrl;
  final String networkId;
  final bool isNative;
  final double? priceUsd;

  const Token({
    required this.address,
    required this.symbol,
    required this.name,
    required this.decimals,
    required this.networkId,
    this.iconUrl,
    this.isNative = false,
    this.priceUsd,
  });

  @override
  List<Object?> get props => [address, networkId];

  Token copyWith({
    String? address,
    String? symbol,
    String? name,
    int? decimals,
    String? iconUrl,
    String? networkId,
    bool? isNative,
    double? priceUsd,
  }) {
    return Token(
      address: address ?? this.address,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      decimals: decimals ?? this.decimals,
      iconUrl: iconUrl ?? this.iconUrl,
      networkId: networkId ?? this.networkId,
      isNative: isNative ?? this.isNative,
      priceUsd: priceUsd ?? this.priceUsd,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'symbol': symbol,
      'name': name,
      'decimals': decimals,
      'iconUrl': iconUrl,
      'networkId': networkId,
      'isNative': isNative,
      'priceUsd': priceUsd,
    };
  }

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      address: json['address'] as String,
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      decimals: json['decimals'] as int,
      iconUrl: json['iconUrl'] as String?,
      networkId: json['networkId'] as String,
      isNative: json['isNative'] as bool? ?? false,
      priceUsd: json['priceUsd'] as double?,
    );
  }

  // Native tokens for each network
  static Token nativeEth = const Token(
    address: '0x0000000000000000000000000000000000000000',
    symbol: 'ETH',
    name: 'Ethereum',
    decimals: 18,
    networkId: 'ethereum',
    isNative: true,
    iconUrl: 'https://assets.coingecko.com/coins/images/279/small/ethereum.png',
  );

  static Token nativeBnb = const Token(
    address: '0x0000000000000000000000000000000000000000',
    symbol: 'BNB',
    name: 'BNB',
    decimals: 18,
    networkId: 'bsc',
    isNative: true,
    iconUrl: 'https://assets.coingecko.com/coins/images/825/small/bnb-icon2_2x.png',
  );

  static Token nativeMatic = const Token(
    address: '0x0000000000000000000000000000000000000000',
    symbol: 'MATIC',
    name: 'Polygon',
    decimals: 18,
    networkId: 'polygon',
    isNative: true,
    iconUrl: 'https://assets.coingecko.com/coins/images/4713/small/matic-token-icon.png',
  );

  static Token nativeAvax = const Token(
    address: '0x0000000000000000000000000000000000000000',
    symbol: 'AVAX',
    name: 'Avalanche',
    decimals: 18,
    networkId: 'avalanche',
    isNative: true,
    iconUrl: 'https://assets.coingecko.com/coins/images/12559/small/Avalanche_Circle_RedWhite_Trans.png',
  );

  static Token getNativeToken(String networkId) {
    switch (networkId) {
      case 'ethereum':
      case 'arbitrum':
      case 'optimism':
        return nativeEth.copyWith(networkId: networkId);
      case 'bsc':
        return nativeBnb;
      case 'polygon':
        return nativeMatic;
      case 'avalanche':
        return nativeAvax;
      default:
        return nativeEth.copyWith(networkId: networkId);
    }
  }
}

class TokenBalance extends Equatable {
  final Token token;
  final BigInt balance;
  final double? valueUsd;

  const TokenBalance({
    required this.token,
    required this.balance,
    this.valueUsd,
  });

  @override
  List<Object?> get props => [token, balance];

  double get formattedBalance {
    if (balance == BigInt.zero) return 0.0;
    return balance / BigInt.from(10).pow(token.decimals);
  }

  String get displayBalance {
    final formatted = formattedBalance;
    if (formatted == 0) return '0';
    if (formatted < 0.0001) return '<0.0001';
    if (formatted < 1) return formatted.toStringAsFixed(6);
    if (formatted < 1000) return formatted.toStringAsFixed(4);
    return formatted.toStringAsFixed(2);
  }

  String get displayValueUsd {
    if (valueUsd == null || valueUsd == 0) return '\$0.00';
    if (valueUsd! < 0.01) return '<\$0.01';
    return '\$${valueUsd!.toStringAsFixed(2)}';
  }
}
