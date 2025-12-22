import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/transaction.dart';
import '../models/network.dart';

class TransactionHistoryService {
  static final TransactionHistoryService _instance = TransactionHistoryService._internal();
  factory TransactionHistoryService() => _instance;
  TransactionHistoryService._internal();

  // API Key - Get from etherscan.io
  static const String _apiKey = 'CA9JQE3SNMD7B3Y73173GQT6Y9RJ87XVQE';
  
  // Etherscan API V2 base URL
  static const String _baseUrlV2 = 'https://api.etherscan.io/v2/api';
  
  // Chain IDs for Etherscan V2 API
  static const Map<String, int> _chainIds = {
    'ethereum': 1,
    'bsc': 56,
    'polygon': 137,
    'arbitrum': 42161,
    'optimism': 10,
    'avalanche': 43114,
  };

  /// Get transaction history for an address (V2 API)
  Future<List<WalletTransaction>> getTransactions({
    required String address,
    required Network network,
    int page = 1,
    int offset = 20,
    String sort = 'desc',
  }) async {
    try {
      final chainId = _chainIds[network.id];
      if (chainId == null) {
        debugPrint('❌ Network not supported: ${network.id}');
        throw Exception('Network not supported: ${network.id}');
      }

      final url = Uri.parse(
        '$_baseUrlV2'
        '?chainid=$chainId'
        '&module=account'
        '&action=txlist'
        '&address=$address'
        '&startblock=0'
        '&endblock=99999999'
        '&page=$page'
        '&offset=$offset'
        '&sort=$sort'
        '&apikey=$_apiKey'
      );

      debugPrint('🔍 Fetching transactions: $url');

      final response = await http.get(url).timeout(const Duration(seconds: 30));
      
      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}...');

      if (response.statusCode != 200) {
        throw Exception('API request failed: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      
      debugPrint('📊 API status: ${data['status']}, message: ${data['message']}');

      if (data['status'] != '1') {
        final result = data['result']?.toString() ?? '';
        if (data['message'] == 'No transactions found' || 
            result.contains('No transactions found') ||
            data['message'] == 'NOTOK' && result.contains('No transactions')) {
          debugPrint('ℹ️ No transactions found');
          return [];
        }
        throw Exception(data['message'] ?? data['result'] ?? 'Unknown error');
      }

      final List<dynamic> txList = data['result'] ?? [];
      debugPrint('✅ Found ${txList.length} transactions');
      
      return txList.map((tx) => _parseTransaction(tx, address, network)).toList();
    } catch (e, stackTrace) {
      debugPrint('❌ getTransactions error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get ERC20 token transfers (V2 API)
  Future<List<WalletTransaction>> getTokenTransfers({
    required String address,
    required Network network,
    String? contractAddress,
    int page = 1,
    int offset = 20,
  }) async {
    try {
      final chainId = _chainIds[network.id];
      if (chainId == null) {
        debugPrint('❌ Network not supported: ${network.id}');
        throw Exception('Network not supported: ${network.id}');
      }

      var urlString = '$_baseUrlV2'
          '?chainid=$chainId'
          '&module=account'
          '&action=tokentx'
          '&address=$address'
          '&page=$page'
          '&offset=$offset'
          '&sort=desc'
          '&apikey=$_apiKey';
      
      if (contractAddress != null) {
        urlString += '&contractaddress=$contractAddress';
      }

      final url = Uri.parse(urlString);
      debugPrint('🔍 Fetching token transfers: $url');

      final response = await http.get(url).timeout(const Duration(seconds: 30));
      
      debugPrint('📥 Token response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('API request failed: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      
      debugPrint('📊 Token API status: ${data['status']}, message: ${data['message']}');

      if (data['status'] != '1') {
        final result = data['result']?.toString() ?? '';
        if (data['message'] == 'No transactions found' ||
            result.contains('No transactions found') ||
            data['message'] == 'NOTOK' && result.contains('No transactions')) {
          debugPrint('ℹ️ No token transfers found');
          return [];
        }
        throw Exception(data['message'] ?? data['result'] ?? 'Unknown error');
      }

      final List<dynamic> txList = data['result'] ?? [];
      debugPrint('✅ Found ${txList.length} token transfers');
      
      return txList.map((tx) => _parseTokenTransfer(tx, address, network)).toList();
    } catch (e, stackTrace) {
      debugPrint('❌ getTokenTransfers error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get all transactions (normal + token) merged and sorted
  Future<List<WalletTransaction>> getAllTransactions({
    required String address,
    required Network network,
    int limit = 50,
  }) async {
    debugPrint('🚀 getAllTransactions started');
    debugPrint('📍 Address: $address');
    debugPrint('📍 Network: ${network.id} (${network.name})');
    
    final List<WalletTransaction> allTx = [];
    final List<String> errors = [];

    // Fetch normal transactions
    try {
      final normalTx = await getTransactions(
        address: address, 
        network: network, 
        offset: limit,
      );
      allTx.addAll(normalTx);
      debugPrint('✅ Normal transactions: ${normalTx.length}');
    } catch (e) {
      debugPrint('⚠️ Normal transactions failed: $e');
      errors.add('Normal: $e');
    }

    // Fetch token transfers
    try {
      final tokenTx = await getTokenTransfers(
        address: address, 
        network: network, 
        offset: limit,
      );
      allTx.addAll(tokenTx);
      debugPrint('✅ Token transfers: ${tokenTx.length}');
    } catch (e) {
      debugPrint('⚠️ Token transfers failed: $e');
      errors.add('Token: $e');
    }

    // If both failed, throw error
    if (allTx.isEmpty && errors.isNotEmpty) {
      debugPrint('❌ All requests failed: $errors');
      throw Exception('Failed to fetch transactions: ${errors.join(', ')}');
    }

    // Remove duplicates by hash
    final seen = <String>{};
    final unique = allTx.where((tx) => seen.add(tx.hash)).toList();

    // Sort by timestamp descending
    unique.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    debugPrint('✅ Total unique transactions: ${unique.length}');

    return unique.take(limit).toList();
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
}