import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/network.dart';

class SwapService {
  static final SwapService _instance = SwapService._internal();
  factory SwapService() => _instance;
  SwapService._internal();

  // 1inch API base URL
  static const String _baseUrl = 'https://api.1inch.dev/swap/v6.0';
  
  // Your 1inch API key - Get from https://portal.1inch.dev/
  static const String _apiKey = 'YOUR_1INCH_API_KEY';
  
  // Chain IDs supported by 1inch
  static const Map<String, int> _supportedChains = {
    'ethereum': 1,
    'bsc': 56,
    'polygon': 137,
    'arbitrum': 42161,
    'optimism': 10,
    'avalanche': 43114,
  };

  // Native token addresses (for 1inch API)
  static const String nativeTokenAddress = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';

  /// Get supported tokens for a network
  Future<List<SwapToken>> getTokens(Network network) async {
    try {
      final chainId = _supportedChains[network.id];
      if (chainId == null) {
        throw Exception('Network not supported for swap');
      }

      final url = Uri.parse('$_baseUrl/$chainId/tokens');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch tokens: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final tokens = <SwapToken>[];

      (data['tokens'] as Map<String, dynamic>).forEach((address, tokenData) {
        tokens.add(SwapToken(
          address: address,
          symbol: tokenData['symbol'],
          name: tokenData['name'],
          decimals: tokenData['decimals'],
          logoUrl: tokenData['logoURI'],
        ));
      });

      // Sort by symbol
      tokens.sort((a, b) => a.symbol.compareTo(b.symbol));

      return tokens;
    } catch (e) {
      throw Exception('Failed to get tokens: $e');
    }
  }

  /// Get swap quote (price estimate without executing)
  Future<SwapQuote> getQuote({
    required Network network,
    required String fromTokenAddress,
    required String toTokenAddress,
    required BigInt amount,
  }) async {
    try {
      final chainId = _supportedChains[network.id];
      if (chainId == null) {
        throw Exception('Network not supported for swap');
      }

      final url = Uri.parse(
        '$_baseUrl/$chainId/quote'
        '?src=$fromTokenAddress'
        '&dst=$toTokenAddress'
        '&amount=${amount.toString()}'
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['description'] ?? 'Failed to get quote');
      }

      final data = json.decode(response.body);

      return SwapQuote(
        fromToken: fromTokenAddress,
        toToken: toTokenAddress,
        fromAmount: BigInt.parse(data['srcAmount']),
        toAmount: BigInt.parse(data['dstAmount']),
        estimatedGas: int.tryParse(data['gas']?.toString() ?? '0') ?? 0,
      );
    } catch (e) {
      throw Exception('Failed to get quote: $e');
    }
  }

  /// Get swap transaction data (for executing swap)
  Future<SwapTransaction> getSwap({
    required Network network,
    required String fromTokenAddress,
    required String toTokenAddress,
    required BigInt amount,
    required String fromAddress,
    double slippage = 1.0, // 1% default slippage
  }) async {
    try {
      final chainId = _supportedChains[network.id];
      if (chainId == null) {
        throw Exception('Network not supported for swap');
      }

      final url = Uri.parse(
        '$_baseUrl/$chainId/swap'
        '?src=$fromTokenAddress'
        '&dst=$toTokenAddress'
        '&amount=${amount.toString()}'
        '&from=$fromAddress'
        '&slippage=$slippage'
        '&disableEstimate=false'
        '&allowPartialFill=false'
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['description'] ?? 'Failed to get swap data');
      }

      final data = json.decode(response.body);
      final tx = data['tx'];

      return SwapTransaction(
        from: tx['from'],
        to: tx['to'],
        data: tx['data'],
        value: BigInt.parse(tx['value']),
        gasLimit: BigInt.parse(tx['gas'].toString()),
        gasPrice: BigInt.parse(tx['gasPrice']),
        fromAmount: BigInt.parse(data['srcAmount']),
        toAmount: BigInt.parse(data['dstAmount']),
      );
    } catch (e) {
      throw Exception('Failed to get swap transaction: $e');
    }
  }

  /// Check if token needs approval before swap
  Future<BigInt> getAllowance({
    required Network network,
    required String tokenAddress,
    required String walletAddress,
  }) async {
    try {
      final chainId = _supportedChains[network.id];
      if (chainId == null) {
        throw Exception('Network not supported');
      }

      // Native token doesn't need approval
      if (tokenAddress.toLowerCase() == nativeTokenAddress.toLowerCase()) {
        return BigInt.from(-1); // Unlimited
      }

      final url = Uri.parse(
        '$_baseUrl/$chainId/approve/allowance'
        '?tokenAddress=$tokenAddress'
        '&walletAddress=$walletAddress'
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Failed to check allowance');
      }

      final data = json.decode(response.body);
      return BigInt.parse(data['allowance']);
    } catch (e) {
      throw Exception('Failed to get allowance: $e');
    }
  }

  /// Get approval transaction data
  Future<ApprovalTransaction> getApprovalTransaction({
    required Network network,
    required String tokenAddress,
    BigInt? amount, // null = unlimited
  }) async {
    try {
      final chainId = _supportedChains[network.id];
      if (chainId == null) {
        throw Exception('Network not supported');
      }

      var urlString = '$_baseUrl/$chainId/approve/transaction'
          '?tokenAddress=$tokenAddress';
      
      if (amount != null) {
        urlString += '&amount=${amount.toString()}';
      }

      final url = Uri.parse(urlString);

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Failed to get approval transaction');
      }

      final data = json.decode(response.body);

      return ApprovalTransaction(
        to: data['to'],
        data: data['data'],
        value: BigInt.parse(data['value']),
        gasLimit: BigInt.from(50000), // Standard approval gas
      );
    } catch (e) {
      throw Exception('Failed to get approval transaction: $e');
    }
  }

  /// Check if network supports swap
  bool isSwapSupported(Network network) {
    return _supportedChains.containsKey(network.id);
  }
}

// Models for swap
class SwapToken {
  final String address;
  final String symbol;
  final String name;
  final int decimals;
  final String? logoUrl;

  SwapToken({
    required this.address,
    required this.symbol,
    required this.name,
    required this.decimals,
    this.logoUrl,
  });

  bool get isNative =>
      address.toLowerCase() == SwapService.nativeTokenAddress.toLowerCase();
}

class SwapQuote {
  final String fromToken;
  final String toToken;
  final BigInt fromAmount;
  final BigInt toAmount;
  final int estimatedGas;

  SwapQuote({
    required this.fromToken,
    required this.toToken,
    required this.fromAmount,
    required this.toAmount,
    required this.estimatedGas,
  });

  double get rate {
    if (fromAmount == BigInt.zero) return 0;
    return toAmount / fromAmount;
  }
}

class SwapTransaction {
  final String from;
  final String to;
  final String data;
  final BigInt value;
  final BigInt gasLimit;
  final BigInt gasPrice;
  final BigInt fromAmount;
  final BigInt toAmount;

  SwapTransaction({
    required this.from,
    required this.to,
    required this.data,
    required this.value,
    required this.gasLimit,
    required this.gasPrice,
    required this.fromAmount,
    required this.toAmount,
  });

  BigInt get estimatedFee => gasLimit * gasPrice;
}

class ApprovalTransaction {
  final String to;
  final String data;
  final BigInt value;
  final BigInt gasLimit;

  ApprovalTransaction({
    required this.to,
    required this.data,
    required this.value,
    required this.gasLimit,
  });
}
