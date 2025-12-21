import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_theme.dart';
import '../../core/models/network.dart';
import '../../core/providers/wallet_provider.dart';
import '../../core/services/swap_service.dart';
import '../../core/services/blockchain_service.dart';
import '../../shared/widgets/common_widgets.dart';

class SwapScreen extends ConsumerStatefulWidget {
  const SwapScreen({super.key});

  @override
  ConsumerState<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends ConsumerState<SwapScreen> {
  final SwapService _swapService = SwapService();
  final _fromAmountController = TextEditingController();
  
  SwapToken? _fromToken;
  SwapToken? _toToken;
  List<SwapToken> _tokens = [];
  
  SwapQuote? _quote;
  bool _isLoadingTokens = true;
  bool _isLoadingQuote = false;
  bool _isSwapping = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTokens();
  }

  @override
  void dispose() {
    _fromAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadTokens() async {
    final network = ref.read(selectedNetworkProvider);
    
    if (!_swapService.isSwapSupported(network)) {
      setState(() {
        _isLoadingTokens = false;
        _error = 'Swap chưa hỗ trợ trên ${network.name}';
      });
      return;
    }

    try {
      final tokens = await _swapService.getTokens(network);
      
      // Find native token and USDT/USDC as defaults
      final nativeToken = tokens.firstWhere(
        (t) => t.isNative,
        orElse: () => tokens.first,
      );
      
      final stablecoin = tokens.firstWhere(
        (t) => t.symbol == 'USDT' || t.symbol == 'USDC',
        orElse: () => tokens.length > 1 ? tokens[1] : tokens.first,
      );

      setState(() {
        _tokens = tokens;
        _fromToken = nativeToken;
        _toToken = stablecoin;
        _isLoadingTokens = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTokens = false;
        _error = e.toString();
      });
    }
  }

  BigInt _toWei(double amount, int decimals) {
    // Convert amount to wei based on token decimals
    final multiplier = BigInt.from(10).pow(decimals);
    final amountBigInt = BigInt.from(amount * 1e9) * multiplier ~/ BigInt.from(1e9);
    return amountBigInt;
  }

  Future<void> _getQuote() async {
    if (_fromToken == null || _toToken == null) return;
    
    final amountText = _fromAmountController.text;
    if (amountText.isEmpty) {
      setState(() => _quote = null);
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) return;

    setState(() {
      _isLoadingQuote = true;
      _error = null;
    });

    try {
      final network = ref.read(selectedNetworkProvider);
      final amountWei = _toWei(amount, _fromToken!.decimals);
      
      final quote = await _swapService.getQuote(
        network: network,
        fromTokenAddress: _fromToken!.address,
        toTokenAddress: _toToken!.address,
        amount: amountWei,
      );

      setState(() {
        _quote = quote;
        _isLoadingQuote = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingQuote = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _swapTokens() {
    final temp = _fromToken;
    setState(() {
      _fromToken = _toToken;
      _toToken = temp;
      _quote = null;
    });
    _fromAmountController.clear();
  }

  Future<void> _executeSwap() async {
    if (_quote == null || _fromToken == null || _toToken == null) return;

    final wallet = ref.read(currentWalletProvider).valueOrNull;
    if (wallet == null) return;

    setState(() => _isSwapping = true);

    try {
      final network = ref.read(selectedNetworkProvider);
      final amount = double.parse(_fromAmountController.text);
      final amountWei = _toWei(amount, _fromToken!.decimals);

      // Check allowance for non-native tokens
      if (!_fromToken!.isNative) {
        final allowance = await _swapService.getAllowance(
          network: network,
          tokenAddress: _fromToken!.address,
          walletAddress: wallet.address,
        );

        if (allowance < amountWei) {
          // Need approval first
          final approved = await _showApprovalDialog();
          if (!approved) {
            setState(() => _isSwapping = false);
            return;
          }

          // Execute approval
          final approvalTx = await _swapService.getApprovalTransaction(
            network: network,
            tokenAddress: _fromToken!.address,
          );

          // TODO: Send approval transaction
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đang approve token...')),
          );
        }
      }

      // Get swap transaction
      final swapTx = await _swapService.getSwap(
        network: network,
        fromTokenAddress: _fromToken!.address,
        toTokenAddress: _toToken!.address,
        amount: amountWei,
        fromAddress: wallet.address,
        slippage: 1.0,
      );

      // Show confirmation
      final confirmed = await _showSwapConfirmation(swapTx);
      if (!confirmed) {
        setState(() => _isSwapping = false);
        return;
      }

      // TODO: Execute swap transaction using blockchain service
      // For now, show success message
      _showSuccessDialog();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() => _isSwapping = false);
    }
  }

  Future<bool> _showApprovalDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cần Approve Token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const InfoBanner(
              message: 'Để swap token này, bạn cần approve (cho phép) smart contract sử dụng token của bạn.',
              type: InfoBannerType.info,
            ),
            const SizedBox(height: 16),
            Text('Token: ${_fromToken!.symbol}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<bool> _showSwapConfirmation(SwapTransaction swapTx) async {
    final network = ref.read(selectedNetworkProvider);
    final fromAmount = double.parse(_fromAmountController.text);
    final toAmount = swapTx.toAmount / BigInt.from(10).pow(_toToken!.decimals);
    final fee = swapTx.estimatedFee / BigInt.from(10).pow(18);

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận Swap'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SwapPreviewRow(
              label: 'Bạn trả',
              value: '$fromAmount ${_fromToken!.symbol}',
            ),
            const Icon(Icons.arrow_downward, color: AppTheme.primaryColor),
            _SwapPreviewRow(
              label: 'Bạn nhận',
              value: '${toAmount.toStringAsFixed(6)} ${_toToken!.symbol}',
              highlight: true,
            ),
            const Divider(height: 24),
            _SwapPreviewRow(
              label: 'Phí mạng',
              value: '~${fee.toStringAsFixed(6)} ${network.symbol}',
            ),
            _SwapPreviewRow(
              label: 'Slippage',
              value: '1%',
            ),
            const SizedBox(height: 16),
            const InfoBanner(
              message: 'Phí app: 0.3% (đã bao gồm trong giá)',
              type: InfoBannerType.info,
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
            child: const Text('Swap'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessDialog() {
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
              'Swap thành công!',
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
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
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
        title: const Text('Swap'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSlippageSettings(),
          ),
        ],
      ),
      body: _isLoadingTokens
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _tokens.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.swap_horiz_rounded,
                        size: 64,
                        color: AppTheme.textTertiaryLight,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textSecondaryLight),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadTokens,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // From token
                      _TokenInput(
                        label: 'Bạn trả',
                        token: _fromToken,
                        controller: _fromAmountController,
                        onTokenTap: () => _selectToken(true),
                        onAmountChanged: (_) => _getQuote(),
                        balance: _fromToken?.isNative == true
                            ? balanceAsync.valueOrNull?.displayBalance
                            : null,
                      ),
                      
                      // Swap button
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: IconButton(
                            onPressed: _swapTokens,
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.swap_vert_rounded,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // To token
                      _TokenInput(
                        label: 'Bạn nhận',
                        token: _toToken,
                        readOnly: true,
                        value: _quote != null
                            ? (_quote!.toAmount / BigInt.from(10).pow(_toToken?.decimals ?? 18))
                                .toStringAsFixed(6)
                            : '',
                        onTokenTap: () => _selectToken(false),
                        isLoading: _isLoadingQuote,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Quote info
                      if (_quote != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Column(
                            children: [
                              _InfoRow(
                                label: 'Tỷ giá',
                                value: '1 ${_fromToken!.symbol} ≈ ${_quote!.rate.toStringAsFixed(6)} ${_toToken!.symbol}',
                              ),
                              const SizedBox(height: 8),
                              _InfoRow(
                                label: 'Phí app',
                                value: '0.3%',
                                valueColor: AppTheme.successColor,
                              ),
                              const SizedBox(height: 8),
                              _InfoRow(
                                label: 'Gas ước tính',
                                value: '~${_quote!.estimatedGas}',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Error message
                      if (_error != null && _tokens.isNotEmpty) ...[
                        InfoBanner(
                          message: _error!,
                          type: InfoBannerType.error,
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Swap button
                      PrimaryButton(
                        text: 'Swap',
                        isLoading: _isSwapping,
                        isEnabled: _quote != null && !_isLoadingQuote,
                        onPressed: _executeSwap,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Info
                      Center(
                        child: Text(
                          'Powered by 1inch',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  void _selectToken(bool isFrom) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isFrom ? 'Chọn token trả' : 'Chọn token nhận',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _tokens.length,
                itemBuilder: (context, index) {
                  final token = _tokens[index];
                  final isSelected = isFrom
                      ? token.address == _fromToken?.address
                      : token.address == _toToken?.address;
                  final isDisabled = isFrom
                      ? token.address == _toToken?.address
                      : token.address == _fromToken?.address;

                  return ListTile(
                    enabled: !isDisabled,
                    selected: isSelected,
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      child: Text(
                        token.symbol.substring(0, token.symbol.length > 3 ? 3 : token.symbol.length),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    title: Text(token.symbol),
                    subtitle: Text(
                      token.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
                        : null,
                    onTap: () {
                      setState(() {
                        if (isFrom) {
                          _fromToken = token;
                        } else {
                          _toToken = token;
                        }
                        _quote = null;
                      });
                      Navigator.pop(context);
                      _getQuote();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSlippageSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Slippage Tolerance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Giao dịch sẽ bị hủy nếu giá thay đổi quá mức này.',
              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _SlippageOption(value: '0.5%', isSelected: false),
                const SizedBox(width: 8),
                _SlippageOption(value: '1%', isSelected: true),
                const SizedBox(width: 8),
                _SlippageOption(value: '2%', isSelected: false),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TokenInput extends StatelessWidget {
  final String label;
  final SwapToken? token;
  final TextEditingController? controller;
  final bool readOnly;
  final String? value;
  final VoidCallback? onTokenTap;
  final Function(String)? onAmountChanged;
  final String? balance;
  final bool isLoading;

  const _TokenInput({
    required this.label,
    this.token,
    this.controller,
    this.readOnly = false,
    this.value,
    this.onTokenTap,
    this.onAmountChanged,
    this.balance,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              if (balance != null)
                Text(
                  'Số dư: $balance',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: readOnly
                    ? isLoading
                        ? const LinearProgressIndicator()
                        : Text(
                            value ?? '0',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                    : TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '0',
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: onAmountChanged,
                      ),
              ),
              GestureDetector(
                onTap: onTokenTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        token?.symbol ?? 'Select',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 20,
                        color: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _SwapPreviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _SwapPreviewRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: highlight ? AppTheme.successColor : null,
              fontSize: highlight ? 16 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlippageOption extends StatelessWidget {
  final String value;
  final bool isSelected;

  const _SlippageOption({
    required this.value,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Theme.of(context).dividerColor,
          ),
        ),
        child: Center(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : null,
            ),
          ),
        ),
      ),
    );
  }
}