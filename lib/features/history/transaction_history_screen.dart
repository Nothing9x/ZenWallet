import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_theme.dart';
import '../../core/models/transaction.dart';
import '../../core/models/network.dart';
import '../../core/providers/wallet_provider.dart';
import '../../core/services/transaction_history_service.dart';
import '../../shared/widgets/common_widgets.dart';

// Transaction history provider
final transactionHistoryProvider = FutureProvider.autoDispose
    .family<List<WalletTransaction>, TransactionHistoryParams>((ref, params) async {
  final service = TransactionHistoryService();
  return await service.getAllTransactions(
    address: params.address,
    network: params.network,
    limit: params.limit,
  );
});

class TransactionHistoryParams {
  final String address;
  final Network network;
  final int limit;

  TransactionHistoryParams({
    required this.address,
    required this.network,
    this.limit = 50,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionHistoryParams &&
          address == other.address &&
          network.id == other.network.id &&
          limit == other.limit;

  @override
  int get hashCode => address.hashCode ^ network.id.hashCode ^ limit.hashCode;
}

class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(currentWalletProvider);
    final network = ref.watch(selectedNetworkProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử giao dịch'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterOptions(context),
          ),
        ],
      ),
      body: walletAsync.when(
        data: (wallet) {
          if (wallet == null) {
            return const Center(child: Text('Không tìm thấy ví'));
          }

          final params = TransactionHistoryParams(
            address: wallet.address,
            network: network,
          );

          final historyAsync = ref.watch(transactionHistoryProvider(params));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(transactionHistoryProvider(params));
            },
            child: historyAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const EmptyState(
                    icon: Icons.history_rounded,
                    title: 'Chưa có giao dịch',
                    subtitle: 'Các giao dịch của bạn sẽ hiển thị ở đây',
                  );
                }

                return _TransactionList(
                  transactions: transactions,
                  network: network,
                  walletAddress: wallet.address,
                );
              },
              loading: () => const _TransactionListSkeleton(),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppTheme.errorColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Không thể tải lịch sử',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(transactionHistoryProvider(params));
                      },
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Lỗi')),
      ),
    );
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lọc giao dịch',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('Tất cả'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward, color: AppTheme.errorColor),
              title: const Text('Gửi đi'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward, color: AppTheme.successColor),
              title: const Text('Nhận'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: AppTheme.primaryColor),
              title: const Text('Swap'),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _TransactionList extends StatelessWidget {
  final List<WalletTransaction> transactions;
  final Network network;
  final String walletAddress;

  const _TransactionList({
    required this.transactions,
    required this.network,
    required this.walletAddress,
  });

  @override
  Widget build(BuildContext context) {
    // Group transactions by date
    final grouped = <String, List<WalletTransaction>>{};
    for (final tx in transactions) {
      final dateKey = _formatDateHeader(tx.timestamp);
      grouped.putIfAbsent(dateKey, () => []).add(tx);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final dateKey = grouped.keys.elementAt(index);
        final dateTxs = grouped[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                dateKey,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),
            ...dateTxs.map((tx) => _TransactionItem(
              transaction: tx,
              network: network,
              onTap: () => _showTransactionDetails(context, tx, network),
            )),
          ],
        );
      },
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final txDate = DateTime(date.year, date.month, date.day);

    if (txDate == today) {
      return 'Hôm nay';
    } else if (txDate == yesterday) {
      return 'Hôm qua';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE', 'vi').format(date);
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  void _showTransactionDetails(
    BuildContext context,
    WalletTransaction tx,
    Network network,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Status icon
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _getStatusColor(tx).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getStatusIcon(tx),
                    size: 32,
                    color: _getStatusColor(tx),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Amount
              Center(
                child: Column(
                  children: [
                    Text(
                      '${tx.isReceive ? '+' : '-'}${tx.displayValue} ${tx.tokenSymbol ?? network.symbol}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: tx.isReceive ? AppTheme.successColor : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(tx).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusText(tx),
                        style: TextStyle(
                          fontSize: 12,
                          color: _getStatusColor(tx),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Details
              _DetailRow(label: 'Loại', value: _getTypeText(tx)),
              _DetailRow(
                label: 'Từ',
                value: tx.shortFrom,
                copyValue: tx.from,
              ),
              _DetailRow(
                label: 'Đến',
                value: tx.shortTo,
                copyValue: tx.to,
              ),
              _DetailRow(
                label: 'Mạng',
                value: network.name,
              ),
              _DetailRow(
                label: 'Hash',
                value: tx.shortHash,
                copyValue: tx.hash,
              ),
              if (tx.blockNumber != null)
                _DetailRow(
                  label: 'Block',
                  value: tx.blockNumber.toString(),
                ),
              _DetailRow(
                label: 'Thời gian',
                value: DateFormat('HH:mm - dd/MM/yyyy').format(tx.timestamp),
              ),
              if (tx.formattedFee > 0)
                _DetailRow(
                  label: 'Phí giao dịch',
                  value: '${tx.formattedFee.toStringAsFixed(6)} ${network.symbol}',
                ),
              
              const SizedBox(height: 24),
              
              // View on explorer button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final url = '${network.explorerTxUrl}/${tx.hash}';
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Xem trên Explorer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(WalletTransaction tx) {
    switch (tx.status) {
      case TransactionStatus.confirmed:
        return tx.isReceive ? AppTheme.successColor : AppTheme.primaryColor;
      case TransactionStatus.pending:
        return AppTheme.warningColor;
      case TransactionStatus.failed:
        return AppTheme.errorColor;
    }
  }

  IconData _getStatusIcon(WalletTransaction tx) {
    switch (tx.status) {
      case TransactionStatus.confirmed:
        return tx.isReceive ? Icons.arrow_downward : Icons.arrow_upward;
      case TransactionStatus.pending:
        return Icons.schedule;
      case TransactionStatus.failed:
        return Icons.error_outline;
    }
  }

  String _getStatusText(WalletTransaction tx) {
    switch (tx.status) {
      case TransactionStatus.confirmed:
        return 'Thành công';
      case TransactionStatus.pending:
        return 'Đang xử lý';
      case TransactionStatus.failed:
        return 'Thất bại';
    }
  }

  String _getTypeText(WalletTransaction tx) {
    switch (tx.type) {
      case TransactionType.send:
        return 'Gửi';
      case TransactionType.receive:
        return 'Nhận';
      case TransactionType.swap:
        return 'Swap';
      case TransactionType.approve:
        return 'Approve';
      case TransactionType.contractInteraction:
        return 'Contract';
    }
  }
}

class _TransactionItem extends StatelessWidget {
  final WalletTransaction transaction;
  final Network network;
  final VoidCallback onTap;

  const _TransactionItem({
    required this.transaction,
    required this.network,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _getIconColor().withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getIcon(),
            color: _getIconColor(),
            size: 22,
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _getTypeText(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '${transaction.isReceive ? '+' : '-'}${transaction.displayValue}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: transaction.isReceive ? AppTheme.successColor : null,
              ),
            ),
          ],
        ),
        subtitle: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              transaction.isReceive
                  ? 'Từ: ${transaction.shortFrom}'
                  : 'Đến: ${transaction.shortTo}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              transaction.tokenSymbol ?? network.symbol,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
        trailing: Icon(
          transaction.isConfirmed
              ? Icons.check_circle
              : transaction.isPending
                  ? Icons.schedule
                  : Icons.error,
          size: 16,
          color: transaction.isConfirmed
              ? AppTheme.successColor
              : transaction.isPending
                  ? AppTheme.warningColor
                  : AppTheme.errorColor,
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (transaction.type) {
      case TransactionType.send:
        return Icons.arrow_upward_rounded;
      case TransactionType.receive:
        return Icons.arrow_downward_rounded;
      case TransactionType.swap:
        return Icons.swap_horiz_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  Color _getIconColor() {
    switch (transaction.type) {
      case TransactionType.receive:
        return AppTheme.successColor;
      case TransactionType.send:
        return AppTheme.errorColor;
      case TransactionType.swap:
        return AppTheme.primaryColor;
      default:
        return AppTheme.infoColor;
    }
  }

  String _getTypeText() {
    switch (transaction.type) {
      case TransactionType.send:
        return 'Gửi';
      case TransactionType.receive:
        return 'Nhận';
      case TransactionType.swap:
        return 'Swap';
      default:
        return 'Contract';
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final String? copyValue;

  const _DetailRow({
    required this.label,
    required this.value,
    this.copyValue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          GestureDetector(
            onTap: copyValue != null
                ? () {
                    Clipboard.setData(ClipboardData(text: copyValue!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã copy'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (copyValue != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.copy,
                    size: 14,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionListSkeleton extends StatelessWidget {
  const _TransactionListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              shape: BoxShape.circle,
            ),
          ),
          title: Container(
            width: 100,
            height: 16,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          subtitle: Container(
            width: 150,
            height: 12,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}
