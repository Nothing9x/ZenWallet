import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_theme.dart';
import '../../core/providers/wallet_provider.dart';
import '../../core/services/blockchain_service.dart';
import '../../shared/widgets/common_widgets.dart';

class SendScreen extends ConsumerStatefulWidget {
  final String? initialAddress;
  
  const SendScreen({super.key, this.initialAddress});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _blockchainService = BlockchainService();

  bool _isLoading = false;
  bool _isEstimatingGas = false;
  BigInt _estimatedGas = BigInt.zero;
  BigInt _gasPrice = BigInt.zero;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null) {
      _addressController.text = widget.initialAddress!;
    }
    _loadGasPrice();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadGasPrice() async {
    try {
      final network = ref.read(selectedNetworkProvider);
      _gasPrice = await _blockchainService.getGasPrice(network);
      setState(() {});
    } catch (e) {
      debugPrint('Failed to load gas price: $e');
    }
  }

  Future<void> _estimateGas() async {
    final address = _addressController.text.trim();
    final amountText = _amountController.text.trim();
    
    if (!_isValidAddress(address) || amountText.isEmpty) {
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) return;

    setState(() => _isEstimatingGas = true);

    try {
      final wallet = ref.read(currentWalletProvider).valueOrNull;
      final network = ref.read(selectedNetworkProvider);
      
      if (wallet == null) return;

      final valueWei = BigInt.from(amount * 1e18);
      
      _estimatedGas = await _blockchainService.estimateGas(
        from: wallet.address,
        to: address,
        value: valueWei,
        network: network,
      );
      
      setState(() {});
    } catch (e) {
      debugPrint('Failed to estimate gas: $e');
    } finally {
      setState(() => _isEstimatingGas = false);
    }
  }

  bool _isValidAddress(String address) {
    if (!address.startsWith('0x')) return false;
    if (address.length != 42) return false;
    return true;
  }

  Future<void> _send() async {
    final address = _addressController.text.trim();
    final amountText = _amountController.text.trim();

    // Validate
    if (!_isValidAddress(address)) {
      setState(() => _error = 'Địa chỉ không hợp lệ');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Số lượng không hợp lệ');
      return;
    }

    // Show confirmation dialog
    final confirmed = await _showConfirmationDialog(address, amount);
    if (!confirmed) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final network = ref.read(selectedNetworkProvider);
      final valueWei = BigInt.from(amount * 1e18);

      final txHash = await _blockchainService.sendTransaction(
        to: address,
        value: valueWei,
        network: network,
      );

      if (mounted) {
        _showSuccessDialog(txHash);
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _showConfirmationDialog(String address, double amount) async {
    final network = ref.read(selectedNetworkProvider);
    final fee = (_estimatedGas * _gasPrice) / BigInt.from(1e18);

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận giao dịch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmRow(label: 'Đến', value: '${address.substring(0, 10)}...${address.substring(address.length - 8)}'),
            _ConfirmRow(label: 'Số lượng', value: '$amount ${network.symbol}'),
            _ConfirmRow(label: 'Phí mạng', value: '~${fee.toStringAsFixed(6)} ${network.symbol}'),
            const Divider(),
            _ConfirmRow(
              label: 'Tổng',
              value: '${(amount + fee).toStringAsFixed(6)} ${network.symbol}',
              isBold: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessDialog(String txHash) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 48,
                color: AppTheme.successColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Gửi thành công!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Giao dịch đang được xử lý trên blockchain.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${txHash.substring(0, 10)}...${txHash.substring(txHash.length - 8)}',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: txHash));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã copy hash')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back
            },
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final network = ref.watch(selectedNetworkProvider);
    final balanceAsync = ref.watch(nativeBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gửi'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Available balance
            balanceAsync.when(
              data: (balance) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Số dư khả dụng'),
                    Text(
                      '${balance.displayBalance} ${network.symbol}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            // Recipient address
            const Text(
              'Địa chỉ người nhận',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                hintText: '0x...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: () {
                        // Navigate to QR scanner
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.content_paste),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          _addressController.text = data!.text!;
                          _estimateGas();
                        }
                      },
                    ),
                  ],
                ),
              ),
              onChanged: (_) => _estimateGas(),
            ),
            const SizedBox(height: 20),

            // Amount
            const Text(
              'Số lượng',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '0.0',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: TextButton(
                  onPressed: () {
                    final balance = balanceAsync.valueOrNull;
                    if (balance != null) {
                      // Use 95% of balance to leave room for gas
                      final maxAmount = (balance.balance * BigInt.from(95)) ~/ BigInt.from(100);
                      final displayAmount = maxAmount / BigInt.from(10).pow(18);
                      _amountController.text = displayAmount.toStringAsFixed(6);
                      _estimateGas();
                    }
                  },
                  child: const Text('MAX'),
                ),
                suffix: Text(network.symbol),
              ),
              onChanged: (_) => _estimateGas(),
            ),
            const SizedBox(height: 20),

            // Gas estimation
            if (_estimatedGas > BigInt.zero || _isEstimatingGas)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Phí mạng ước tính'),
                        _isEstimatingGas
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                '~${((_estimatedGas * _gasPrice) / BigInt.from(1e18)).toStringAsFixed(6)} ${network.symbol}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Error
            if (_error != null) ...[
              InfoBanner(
                message: _error!,
                type: InfoBannerType.error,
              ),
              const SizedBox(height: 20),
            ],

            // Send button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _send,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Gửi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _ConfirmRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}