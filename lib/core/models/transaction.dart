enum TransactionStatus {
  pending,
  confirmed,
  failed,
}

enum TransactionType {
  send,
  receive,
  swap,
  approve,
  contractInteraction,
}

class WalletTransaction {
  final String hash;
  final String from;
  final String to;
  final BigInt value;
  final BigInt gasUsed;
  final BigInt gasPrice;
  final DateTime timestamp;
  final TransactionStatus status;
  final TransactionType type;
  final String networkId;
  final String? tokenSymbol;
  final int? tokenDecimals;
  final int? blockNumber;
  final String? data;

  WalletTransaction({
    required this.hash,
    required this.from,
    required this.to,
    required this.value,
    required this.gasUsed,
    required this.gasPrice,
    required this.timestamp,
    required this.status,
    required this.type,
    required this.networkId,
    this.tokenSymbol,
    this.tokenDecimals,
    this.blockNumber,
    this.data,
  });

  // Computed properties
  bool get isReceive => type == TransactionType.receive;
  bool get isSend => type == TransactionType.send;
  bool get isSwap => type == TransactionType.swap;
  bool get isPending => status == TransactionStatus.pending;
  bool get isConfirmed => status == TransactionStatus.confirmed;
  bool get isFailed => status == TransactionStatus.failed;

  BigInt get fee => gasUsed * gasPrice;

  double get formattedValue {
    final decimals = tokenDecimals ?? 18;
    return value / BigInt.from(10).pow(decimals);
  }

  double get formattedFee {
    return fee / BigInt.from(10).pow(18);
  }

  String get displayValue {
    final val = formattedValue;
    if (val == 0) return '0';
    if (val < 0.0001) return '<0.0001';
    if (val < 1) return val.toStringAsFixed(6);
    if (val < 1000) return val.toStringAsFixed(4);
    return val.toStringAsFixed(2);
  }

  String get shortHash {
    if (hash.length < 16) return hash;
    return '${hash.substring(0, 10)}...${hash.substring(hash.length - 6)}';
  }

  String get shortFrom {
    if (from.length < 12) return from;
    return '${from.substring(0, 6)}...${from.substring(from.length - 4)}';
  }

  String get shortTo {
    if (to.length < 12) return to;
    return '${to.substring(0, 6)}...${to.substring(to.length - 4)}';
  }

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'hash': hash,
      'from': from,
      'to': to,
      'value': value.toString(),
      'gasUsed': gasUsed.toString(),
      'gasPrice': gasPrice.toString(),
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'type': type.name,
      'networkId': networkId,
      'tokenSymbol': tokenSymbol,
      'tokenDecimals': tokenDecimals,
      'blockNumber': blockNumber,
      'data': data,
    };
  }

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      hash: json['hash'],
      from: json['from'],
      to: json['to'],
      value: BigInt.parse(json['value']),
      gasUsed: BigInt.parse(json['gasUsed']),
      gasPrice: BigInt.parse(json['gasPrice']),
      timestamp: DateTime.parse(json['timestamp']),
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TransactionStatus.pending,
      ),
      type: TransactionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TransactionType.send,
      ),
      networkId: json['networkId'],
      tokenSymbol: json['tokenSymbol'],
      tokenDecimals: json['tokenDecimals'],
      blockNumber: json['blockNumber'],
      data: json['data'],
    );
  }

  WalletTransaction copyWith({
    String? hash,
    String? from,
    String? to,
    BigInt? value,
    BigInt? gasUsed,
    BigInt? gasPrice,
    DateTime? timestamp,
    TransactionStatus? status,
    TransactionType? type,
    String? networkId,
    String? tokenSymbol,
    int? tokenDecimals,
    int? blockNumber,
    String? data,
  }) {
    return WalletTransaction(
      hash: hash ?? this.hash,
      from: from ?? this.from,
      to: to ?? this.to,
      value: value ?? this.value,
      gasUsed: gasUsed ?? this.gasUsed,
      gasPrice: gasPrice ?? this.gasPrice,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      type: type ?? this.type,
      networkId: networkId ?? this.networkId,
      tokenSymbol: tokenSymbol ?? this.tokenSymbol,
      tokenDecimals: tokenDecimals ?? this.tokenDecimals,
      blockNumber: blockNumber ?? this.blockNumber,
      data: data ?? this.data,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletTransaction && hash == other.hash;

  @override
  int get hashCode => hash.hashCode;
}
