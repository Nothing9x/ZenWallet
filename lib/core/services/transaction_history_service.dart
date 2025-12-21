import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/transaction.dart';
import '../models/network.dart';

class TransactionHistoryService {
  static final TransactionHistoryService _instance = TransactionHistoryService._internal();
  factory TransactionHistoryService() => _instance;
  TransactionHistoryService._internal();

  // API Keys - In production, use environment variables
  // Free tier: 5 calls/sec, 100,000 calls/day
  static const Map<String, String> _apiKeys = {
    'ethereum': 'YourEtherscanApiKey', // Get from etherscan.io
    'bsc': 'YourBscscanApiKey', // Get from bscscan.com
    'polygon': 'YourPolygonscanApiKey', // Get from polygonscan.com
    'arbitrum': 'YourArbiscanApiKey', // Get from arbiscan.io
    'optimism': 'YourOptimisticEtherscanApiKey',
    'avalanche': 'YourSnowtraceApiKey',
  };

  static const Map<String, String> _apiUrls = {
    'ethereum': 'https://api.etherscan.io/api',
    'bsc': 'https://api.bscscan.com/api',
    'polygon': 'https://api.polygonscan.com/api',
    'arbitrum': 'https://api.arbiscan.io/api',
    'optimism': 'https://api-optimistic.etherscan.io/api',
    'avalanche': 'https://api.snowtrace.io/api',
  };

  /// Get transaction history for an address
  Future<List<WalletTransaction>> getTransactions({
    required String address,
    required Network network,
    int page = 1,
    int offset = 20,
    String sort = 'desc',
  }) async {
    try {
      final apiUrl = _apiUrls[network.id];
      final apiKey = _apiKeys[network.id];
      
      if (apiUrl == null) {
        throw Exception('Network not supported: ${network.id}');
      }

      // Build URL for normal transactions
      final url = Uri.parse(
        '$apiUrl?module=account&action=txlist'
        '&address=$address'
        '&startblock=0'
        '&endblock=99999999'
        '&page=$page'
        '&offset=$offset'
        '&sort=$sort'
        '${apiKey != null ? '&apikey=$apiKey' : ''}'
      );

      final response = await http.get(url).timeout(const Duration(seconds: 30));
      
      if (response.statusCode != 200) {
        throw Exception('API request failed: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      
      if (data['status'] != '1') {
        // No transactions found or error
        if (data['message'] == 'No transactions found') {
          return [];
        }
        throw Exception(data['message'] ?? 'Unknown error');
      }

      final List<dynamic> txList = data['result'];
      
      return txList.map((tx) => _parseTransaction(tx, address, network)).toList();
    } catch (e) {
      throw Exception('Failed to fetch transactions: $e');
    }
  }

  /// Get ERC20 token transfers
  Future<List<WalletTransaction>> getTokenTransfers({
    required String address,
    required Network network,
    String? contractAddress,
    int page = 1,
    int offset = 20,
  }) async {
    try {
      final apiUrl = _apiUrls[network.id];
      final apiKey = _apiKeys[network.id];
      
      if (apiUrl == null) {
        throw Exception('Network not supported: ${network.id}');
      }

      var urlString = '$apiUrl?module=account&action=tokentx'
          '&address=$address'
          '&page=$page'
          '&offset=$offset'
          '&sort=desc'
          '${apiKey != null ? '&apikey=$apiKey' : ''}';
      
      if (contractAddress != null) {
        urlString += '&contractaddress=$contractAddress';
      }

      final url = Uri.parse(urlString);
      final response = await http.get(url).timeout(const Duration(seconds: 30));
      
      if (response.statusCode != 200) {
        throw Exception('API request failed: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      
      if (data['status'] != '1') {
        if (data['message'] == 'No transactions found') {
          return [];
        }
        throw Exception(data['message'] ?? 'Unknown error');
      }

      final List<dynamic> txList = data['result'];
      
      return txList.map((tx) => _parseTokenTransfer(tx, address, network)).toList();
    } catch (e) {
      throw Exception('Failed to fetch token transfers: $e');
    }
  }

  /// Get internal transactions (contract calls)
  Future<List<WalletTransaction>> getInternalTransactions({
    required String address,
    required Network network,
    int page = 1,
    int offset = 20,
  }) async {
    try {
      final apiUrl = _apiUrls[network.id];
      final apiKey = _apiKeys[network.id];
      
      if (apiUrl == null) {
        throw Exception('Network not supported: ${network.id}');
      }

      final url = Uri.parse(
        '$apiUrl?module=account&action=txlistinternal'
        '&address=$address'
        '&startblock=0'
        '&endblock=99999999'
        '&page=$page'
        '&offset=$offset'
        '&sort=desc'
        '${apiKey != null ? '&apikey=$apiKey' : ''}'
      );

      final response = await http.get(url).timeout(const Duration(seconds: 30));
      
      if (response.statusCode != 200) {
        throw Exception('API request failed: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      
      if (data['status'] != '1') {
        if (data['message'] == 'No transactions found') {
          return [];
        }
        throw Exception(data['message'] ?? 'Unknown error');
      }

      final List<dynamic> txList = data['result'];
      
      return txList.map((tx) => _parseInternalTransaction(tx, address, network)).toList();
    } catch (e) {
      throw Exception('Failed to fetch internal transactions: $e');
    }
  }

  /// Get all transactions (normal + token + internal) merged and sorted
  Future<List<WalletTransaction>> getAllTransactions({
    required String address,
    required Network network,
    int limit = 50,
  }) async {
    try {
      // Fetch all types in parallel
      final results = await Future.wait([
        getTransactions(address: address, network: network, offset: limit),
        getTokenTransfers(address: address, network: network, offset: limit),
      ]);

      // Merge and sort by timestamp
      final allTx = <WalletTransaction>[
        ...results[0],
        ...results[1],
      ];

      // Remove duplicates by hash
      final seen = <String>{};
      final unique = allTx.where((tx) => seen.add(tx.hash)).toList();

      // Sort by timestamp descending
      unique.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return unique.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to fetch all transactions: $e');
    }
  }

  WalletTransaction _parseTransaction(
    Map<String, dynamic> tx,
    String walletAddress,
    Network network,
  ) {
    final from = tx['from']?.toString().toLowerCase() ?? '';
    final to = tx['to']?.toString().toLowerCase() ?? '';
    final isReceive = to == walletAddress.toLowerCase();
    
    return WalletTransaction(
      hash: tx['hash'] ?? '',
      from: tx['from'] ?? '',
      to: tx['to'] ?? '',
      value: BigInt.tryParse(tx['value'] ?? '0') ?? BigInt.zero,
      gasUsed: BigInt.tryParse(tx['gasUsed'] ?? '0') ?? BigInt.zero,
      gasPrice: BigInt.tryParse(tx['gasPrice'] ?? '0') ?? BigInt.zero,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (int.tryParse(tx['timeStamp'] ?? '0') ?? 0) * 1000,
      ),
      status: tx['txreceipt_status'] == '1' || tx['isError'] == '0'
          ? TransactionStatus.confirmed
          : TransactionStatus.failed,
      type: isReceive ? TransactionType.receive : TransactionType.send,
      networkId: network.id,
      tokenSymbol: network.symbol,
      tokenDecimals: network.decimals,
      blockNumber: int.tryParse(tx['blockNumber'] ?? '0'),
    );
  }

  WalletTransaction _parseTokenTransfer(
    Map<String, dynamic> tx,
    String walletAddress,
    Network network,
  ) {
    final from = tx['from']?.toString().toLowerCase() ?? '';
    final to = tx['to']?.toString().toLowerCase() ?? '';
    final isReceive = to == walletAddress.toLowerCase();
    
    return WalletTransaction(
      hash: tx['hash'] ?? '',
      from: tx['from'] ?? '',
      to: tx['to'] ?? '',
      value: BigInt.tryParse(tx['value'] ?? '0') ?? BigInt.zero,
      gasUsed: BigInt.tryParse(tx['gasUsed'] ?? '0') ?? BigInt.zero,
      gasPrice: BigInt.tryParse(tx['gasPrice'] ?? '0') ?? BigInt.zero,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (int.tryParse(tx['timeStamp'] ?? '0') ?? 0) * 1000,
      ),
      status: TransactionStatus.confirmed,
      type: isReceive ? TransactionType.receive : TransactionType.send,
      networkId: network.id,
      tokenSymbol: tx['tokenSymbol'] ?? 'TOKEN',
      tokenDecimals: int.tryParse(tx['tokenDecimal'] ?? '18') ?? 18,
      blockNumber: int.tryParse(tx['blockNumber'] ?? '0'),
    );
  }

  WalletTransaction _parseInternalTransaction(
    Map<String, dynamic> tx,
    String walletAddress,
    Network network,
  ) {
    final from = tx['from']?.toString().toLowerCase() ?? '';
    final to = tx['to']?.toString().toLowerCase() ?? '';
    final isReceive = to == walletAddress.toLowerCase();
    
    return WalletTransaction(
      hash: tx['hash'] ?? '',
      from: tx['from'] ?? '',
      to: tx['to'] ?? '',
      value: BigInt.tryParse(tx['value'] ?? '0') ?? BigInt.zero,
      gasUsed: BigInt.zero, // Internal tx don't have separate gas
      gasPrice: BigInt.zero,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (int.tryParse(tx['timeStamp'] ?? '0') ?? 0) * 1000,
      ),
      status: tx['isError'] == '0'
          ? TransactionStatus.confirmed
          : TransactionStatus.failed,
      type: isReceive ? TransactionType.receive : TransactionType.contractInteraction,
      networkId: network.id,
      tokenSymbol: network.symbol,
      tokenDecimals: network.decimals,
      blockNumber: int.tryParse(tx['blockNumber'] ?? '0'),
    );
  }
}
