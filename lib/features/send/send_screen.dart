import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_theme.dart';
import '../../core/providers/wallet_provider.dart';
import '../../core/services/blockchain_service.dart';
import '../../shared/widgets/common_widgets.dart';

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  
  bool _isLoading = false;
  bool _isEstimatingFee = false;
  BigInt? _estimatedFee;
  String? _feeError;

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(nativeBalanceProvider);
    final network = ref.watch(selectedNetworkProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gửi'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Balance info
              balanceAsync.when(
                data: (balance) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Số dư khả dụng',
                            style: TextStyle(fontSize: 12),
                          ),
                          Text(
                            '${balance.displayBalance} ${balance.token.symbol}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),

              // Recipient address
              CustomTextField(
                label: 'Địa chỉ người nhận',
                hint: '0x...',
                controller: _addressController,
                keyboardType: TextInputType.text,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      onPressed: () {
                        // TODO: Open QR scanner
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Quét QR sẽ có trong bản cập nhật'),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.paste_rounded),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          _addressController.text = data!.text!;
                          _estimateFee();
                        }
                      },
                    ),
                  ],
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập địa chỉ';
                  }
                  final address = value.trim();
                  if (!address.startsWith('0x') || address.length != 42) {
                    return 'Địa chỉ không hợp lệ';
                  }
                  return null;
                },
                onChanged: (_) => _estimateFee(),
              ),
              const SizedBox(height: 20),

              // Amount
              CustomTextField(
                label: 'Số lượng',
                hint: '0.0',
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                suffixIcon: TextButton(
                  onPressed: () {
                    final balance = balanceAsync.valueOrNull;
                    if (balance != null) {
                      // Set max amount (leave some for gas)
                      final maxAmount = balance.formattedBalance * 0.95;
                      _amountController.text = maxAmount.toStringAsFixed(6);
                      _estimateFee();
                    }
                  },
                  child: const Text('MAX'),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập số lượng';
                  }
                  final amount = double.tryParse(value.trim());
                  if (amount == null || amount <= 0) {
                    return 'Số lượng không hợp lệ';
                  }
                  final balance = balanceAsync.valueOrNull;
                  if (balance != null && amount > balance.formattedBalance) {
                    return 'Số dư không đủ';
                  }
                  return null;
                },
                onChanged: (_) => _estimateFee(),
              ),
              const SizedBox(height: 24),

              // Fee estimation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Phí mạng (Gas)',
                          style: TextStyle(fontSize: 14),
                        ),
                        if (_isEstimatingFee)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else if (_estimatedFee != null)
                          Text(
                            '~${(_estimatedFee! / BigInt.from(10).pow(18)).toStringAsFixed(6)} ${network.symbol}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else
                          Text(
                            _feeError ?? 'Nhập thông tin để ước tính',
                            style: TextStyle(
                              color: _feeError != null
                                  ? AppTheme.errorColor
                                  : Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const InfoBanner(
                      message: 'Phí mạng được trả cho validators để xử lý giao dịch. '
                          'VWallet không thu thêm bất kỳ phí nào.',
                      type: InfoBannerType.info,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Warning
              const InfoBanner(
                message: 'Hãy kiểm tra kỹ địa chỉ trước khi gửi. '
                    'Giao dịch blockchain không thể hoàn tác.',
                type: InfoBannerType.warning,
              ),
              const SizedBox(height: 24),

              // Send button
              PrimaryButton(
                text: 'Xác nhận gửi',
                isLoading: _isLoading,
                onPressed: () => _confirmSend(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _estimateFee() async {
    final address = _addressController.text.trim();
    final amountText = _amountController.text.trim();
    
    if (address.length != 42 || !address.startsWith('0x')) {
      return;
    }
    
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      return;
    }

    setState(() {
      _isEstimatingFee = true;
      _feeError = null;
    });

    try {
      final network = ref.read(selectedNetworkProvider);
      final wallet = ref.read(currentWalletProvider).valueOrNull;
      
      if (wallet == null) return;

      final blockchain = BlockchainService();
      final valueWei = BigInt.from(amount * 1e18);
      
      final gasLimit = await blockchain.estimateGas(
        from: wallet.address,
        to: address,
        value: valueWei,
        network: network,
      );
      
      final gasPrice = await blockchain.getGasPrice(network);
      
      setState(() {
        _estimatedFee = gasLimit * gasPrice;
        _isEstimatingFee = false;
      });
    } catch (e) {
      setState(() {
        _feeError = 'Không thể ước tính phí';
        _isEstimatingFee = false;
      });
    }
  }

  Future<void> _confirmSend(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    final address = _addressController.text.trim();
    final amount = double.parse(_amountController.text.trim());
    final network = ref.read(selectedNetworkProvider);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận giao dịch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmRow(
              label: 'Gửi đến',
              value: '${address.substring(0, 8)}...${address.substring(address.length - 6)}',
            ),
            const SizedBox(height: 12),
            _ConfirmRow(
              label: 'Số lượng',
              value: '$amount ${network.symbol}',
            ),
            if (_estimatedFee != null) ...[
              const SizedBox(height: 12),
              _ConfirmRow(
                label: 'Phí ước tính',
                value: '~${(_estimatedFee! / BigInt.from(10).pow(18)).toStringAsFixed(6)} ${network.symbol}',
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Mạng: ${network.name}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
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
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final blockchain = BlockchainService();
      final valueWei = BigInt.from(amount * 1e18);
      
      final txHash = await blockchain.sendTransaction(
        to: address,
        value: valueWei,
        network: network,
      );

      if (mounted) {
        Navigator.pop(context);
        _showSuccessDialog(context, txHash, network.explorerTxUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog(BuildContext context, String txHash, String explorerUrl) {
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
              'Giao dịch đã gửi!',
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
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: txHash));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã copy hash giao dịch'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: Open explorer
            },
            child: const Text('Xem trên Explorer'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;

  const _ConfirmRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
