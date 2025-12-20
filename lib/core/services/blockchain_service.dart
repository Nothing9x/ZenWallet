import 'dart:typed_data';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';

import '../models/network.dart';
import '../models/token.dart';
import 'wallet_service.dart';

class BlockchainService {
  static final BlockchainService _instance = BlockchainService._internal();
  factory BlockchainService() => _instance;
  BlockchainService._internal();

  final WalletService _walletService = WalletService();
  final Map<String, Web3Client> _clients = {};

  /// Get or create Web3Client for a network
  Web3Client _getClient(Network network) {
    if (!_clients.containsKey(network.id)) {
      final httpClient = Client();
      _clients[network.id] = Web3Client(network.rpcUrl, httpClient);
    }
    return _clients[network.id]!;
  }

  /// Get native token balance
  Future<BigInt> getNativeBalance(String address, Network network) async {
    try {
      final client = _getClient(network);
      final ethAddress = EthereumAddress.fromHex(address);
      final balance = await client.getBalance(ethAddress);
      return balance.getInWei;
    } catch (e) {
      throw Exception('Failed to get balance: $e');
    }
  }

  /// Get ERC20 token balance
  Future<BigInt> getTokenBalance(
    String address,
    String tokenAddress,
    Network network,
  ) async {
    try {
      final client = _getClient(network);
      
      // ERC20 balanceOf ABI
      final contract = DeployedContract(
        ContractAbi.fromJson(_erc20Abi, 'ERC20'),
        EthereumAddress.fromHex(tokenAddress),
      );
      
      final balanceFunction = contract.function('balanceOf');
      final result = await client.call(
        contract: contract,
        function: balanceFunction,
        params: [EthereumAddress.fromHex(address)],
      );
      
      return result.first as BigInt;
    } catch (e) {
      throw Exception('Failed to get token balance: $e');
    }
  }

  /// Get token balances for an address
  Future<List<TokenBalance>> getTokenBalances(
    String address,
    Network network,
    List<Token> tokens,
  ) async {
    final balances = <TokenBalance>[];
    
    for (final token in tokens) {
      try {
        BigInt balance;
        if (token.isNative) {
          balance = await getNativeBalance(address, network);
        } else {
          balance = await getTokenBalance(address, token.address, network);
        }
        
        balances.add(TokenBalance(
          token: token,
          balance: balance,
        ));
      } catch (e) {
        // Add zero balance on error
        balances.add(TokenBalance(
          token: token,
          balance: BigInt.zero,
        ));
      }
    }
    
    return balances;
  }

  /// Get current gas price
  Future<BigInt> getGasPrice(Network network) async {
    try {
      final client = _getClient(network);
      final gasPrice = await client.getGasPrice();
      return gasPrice.getInWei;
    } catch (e) {
      throw Exception('Failed to get gas price: $e');
    }
  }

  /// Estimate gas for a transaction
  Future<BigInt> estimateGas({
    required String from,
    required String to,
    required BigInt value,
    required Network network,
    String? data,
  }) async {
    try {
      final client = _getClient(network);
      
      final gas = await client.estimateGas(
        sender: EthereumAddress.fromHex(from),
        to: EthereumAddress.fromHex(to),
        value: EtherAmount.inWei(value),
        data: data != null ? Uint8List.fromList(hexToBytes(data)) : null,
      );
      
      // Add 20% buffer
      return gas * BigInt.from(120) ~/ BigInt.from(100);
    } catch (e) {
      // Default gas limit
      return BigInt.from(21000);
    }
  }

  /// Send native token transaction
  Future<String> sendTransaction({
    required String to,
    required BigInt value,
    required Network network,
    BigInt? gasLimit,
    BigInt? gasPrice,
  }) async {
    try {
      final client = _getClient(network);
      final credentials = await _walletService.getCredentials();
      
      if (credentials == null) {
        throw Exception('No wallet credentials found');
      }

      final address = credentials.address.hexEip55;
      
      // Get gas price if not provided
      gasPrice ??= await getGasPrice(network);
      
      // Estimate gas if not provided
      gasLimit ??= await estimateGas(
        from: address,
        to: to,
        value: value,
        network: network,
      );

      final txHash = await client.sendTransaction(
        credentials,
        Transaction(
          to: EthereumAddress.fromHex(to),
          value: EtherAmount.inWei(value),
          gasPrice: EtherAmount.inWei(gasPrice),
          maxGas: gasLimit.toInt(),
        ),
        chainId: network.chainId,
      );

      return txHash;
    } catch (e) {
      throw Exception('Failed to send transaction: $e');
    }
  }

  /// Send ERC20 token transaction
  Future<String> sendTokenTransaction({
    required String tokenAddress,
    required String to,
    required BigInt amount,
    required Network network,
    BigInt? gasLimit,
    BigInt? gasPrice,
  }) async {
    try {
      final client = _getClient(network);
      final credentials = await _walletService.getCredentials();
      
      if (credentials == null) {
        throw Exception('No wallet credentials found');
      }

      final contract = DeployedContract(
        ContractAbi.fromJson(_erc20Abi, 'ERC20'),
        EthereumAddress.fromHex(tokenAddress),
      );
      
      final transferFunction = contract.function('transfer');
      
      // Get gas price if not provided
      gasPrice ??= await getGasPrice(network);
      
      // Estimate gas for token transfer
      gasLimit ??= BigInt.from(100000); // Default for ERC20 transfers

      final txHash = await client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract,
          function: transferFunction,
          parameters: [EthereumAddress.fromHex(to), amount],
          gasPrice: EtherAmount.inWei(gasPrice),
          maxGas: gasLimit.toInt(),
        ),
        chainId: network.chainId,
      );

      return txHash;
    } catch (e) {
      throw Exception('Failed to send token transaction: $e');
    }
  }

  /// Get transaction receipt
  Future<TransactionReceipt?> getTransactionReceipt(
    String txHash,
    Network network,
  ) async {
    try {
      final client = _getClient(network);
      return await client.getTransactionReceipt(txHash);
    } catch (e) {
      return null;
    }
  }

  /// Get transaction details
  Future<TransactionInformation?> getTransaction(
    String txHash,
    Network network,
  ) async {
    try {
      final client = _getClient(network);
      return await client.getTransactionByHash(txHash);
    } catch (e) {
      return null;
    }
  }

  /// Get current block number
  Future<int> getBlockNumber(Network network) async {
    try {
      final client = _getClient(network);
      return await client.getBlockNumber();
    } catch (e) {
      throw Exception('Failed to get block number: $e');
    }
  }

  /// Dispose all clients
  void dispose() {
    for (final client in _clients.values) {
      client.dispose();
    }
    _clients.clear();
  }
}

// Minimal ERC20 ABI for balance and transfer
const String _erc20Abi = '''
[
  {
    "constant": true,
    "inputs": [{"name": "_owner", "type": "address"}],
    "name": "balanceOf",
    "outputs": [{"name": "balance", "type": "uint256"}],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {"name": "_to", "type": "address"},
      {"name": "_value", "type": "uint256"}
    ],
    "name": "transfer",
    "outputs": [{"name": "", "type": "bool"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "decimals",
    "outputs": [{"name": "", "type": "uint8"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "symbol",
    "outputs": [{"name": "", "type": "string"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "name",
    "outputs": [{"name": "", "type": "string"}],
    "type": "function"
  }
]
''';

/// Helper function to convert hex string to bytes
List<int> hexToBytes(String hex) {
  String cleanHex = hex.startsWith('0x') ? hex.substring(2) : hex;
  final result = <int>[];
  for (int i = 0; i < cleanHex.length; i += 2) {
    result.add(int.parse(cleanHex.substring(i, i + 2), radix: 16));
  }
  return result;
}
