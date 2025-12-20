import 'package:equatable/equatable.dart';

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

class WalletTransaction extends Equatable {
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
  final String? errorMessage;

  const WalletTransaction({
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
    this.errorMessage,
  });

  @override
  List<Object?> get props => [hash, networkId];

  bool get isPending => status == TransactionStatus.pending;
  bool get isConfirmed => status == TransactionStatus.confirmed;
  bool get isFailed => status == TransactionStatus.failed;
  bool get isSend => type == TransactionType.send;
  bool get isReceive => type == TransactionType.receive;

  BigInt get totalFee => gasUsed * gasPrice;

  double get formattedValue {
    final decimals = tokenDecimals ?? 18;
    if (value == BigInt.zero) return 0.0;
    return value / BigInt.from(10).pow(decimals);
  }

  double get formattedFee {
    if (totalFee == BigInt.zero) return 0.0;
    return totalFee / BigInt.from(10).pow(18);
  }

  String get displayValue {
    final formatted = formattedValue;
    if (formatted == 0) return '0';
    if (formatted < 0.0001) return '<0.0001';
    if (formatted < 1) return formatted.toStringAsFixed(6);
    return formatted.toStringAsFixed(4);
  }

  String get shortHash {
    if (hash.length < 16) return hash;
    return '${hash.substring(0, 8)}...${hash.substring(hash.length - 6)}';
  }

  String get shortFrom {
    if (from.length < 16) return from;
    return '${from.substring(0, 8)}...${from.substring(from.length - 4)}';
  }

  String get shortTo {
    if (to.length < 16) return to;
    return '${to.substring(0, 8)}...${to.substring(to.length - 4)}';
  }

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
      'errorMessage': errorMessage,
    };
  }

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      hash: json['hash'] as String,
      from: json['from'] as String,
      to: json['to'] as String,
      value: BigInt.parse(json['value'] as String),
      gasUsed: BigInt.parse(json['gasUsed'] as String),
      gasPrice: BigInt.parse(json['gasPrice'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: TransactionStatus.values.byName(json['status'] as String),
      type: TransactionType.values.byName(json['type'] as String),
      networkId: json['networkId'] as String,
      tokenSymbol: json['tokenSymbol'] as String?,
      tokenDecimals: json['tokenDecimals'] as int?,
      blockNumber: json['blockNumber'] as int?,
      errorMessage: json['errorMessage'] as String?,
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
    String? errorMessage,
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
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
