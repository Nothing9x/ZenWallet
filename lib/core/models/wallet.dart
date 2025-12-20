import 'package:equatable/equatable.dart';

class Wallet extends Equatable {
  final String address;
  final String name;
  final DateTime createdAt;
  final bool isImported;
  final int accountIndex;

  const Wallet({
    required this.address,
    required this.name,
    required this.createdAt,
    this.isImported = false,
    this.accountIndex = 0,
  });

  @override
  List<Object?> get props => [address];

  String get shortAddress {
    if (address.length < 16) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 6)}';
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'isImported': isImported,
      'accountIndex': accountIndex,
    };
  }

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      address: json['address'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isImported: json['isImported'] as bool? ?? false,
      accountIndex: json['accountIndex'] as int? ?? 0,
    );
  }

  Wallet copyWith({
    String? address,
    String? name,
    DateTime? createdAt,
    bool? isImported,
    int? accountIndex,
  }) {
    return Wallet(
      address: address ?? this.address,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      isImported: isImported ?? this.isImported,
      accountIndex: accountIndex ?? this.accountIndex,
    );
  }
}

class WalletState extends Equatable {
  final Wallet? wallet;
  final String? selectedNetworkId;
  final bool isLoading;
  final String? error;

  const WalletState({
    this.wallet,
    this.selectedNetworkId = 'ethereum',
    this.isLoading = false,
    this.error,
  });

  @override
  List<Object?> get props => [wallet, selectedNetworkId, isLoading, error];

  bool get hasWallet => wallet != null;

  WalletState copyWith({
    Wallet? wallet,
    String? selectedNetworkId,
    bool? isLoading,
    String? error,
  }) {
    return WalletState(
      wallet: wallet ?? this.wallet,
      selectedNetworkId: selectedNetworkId ?? this.selectedNetworkId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
