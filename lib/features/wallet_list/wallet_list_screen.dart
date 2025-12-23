import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_theme.dart';
import '../../core/models/wallet.dart';
import '../../core/models/network.dart';
import '../../core/models/token.dart';
import '../../core/providers/wallet_provider.dart';
import '../../core/services/wallet_service.dart';
import '../../core/services/blockchain_service.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../onboarding/import_wallet_screen.dart';

// Provider for all wallets
final allWalletsProvider = FutureProvider<List<WalletInfo>>((ref) async {
  final walletService = WalletService();
  return await walletService.getAllWallets();
});

// Provider for wallet balances (cached)
final walletBalanceProvider = FutureProvider.family<double, String>((ref, address) async {
  final blockchainService = BlockchainService();
  final network = Network.ethereum;
  
  try {
    final balance = await blockchainService.getNativeBalance(address, network);
    return balance / BigInt.from(10).pow(18);
  } catch (e) {
    return 0.0;
  }
});

class WalletListScreen extends ConsumerStatefulWidget {
  const WalletListScreen({super.key});

  @override
  ConsumerState<WalletListScreen> createState() => _WalletListScreenState();
}

class _WalletListScreenState extends ConsumerState<WalletListScreen> {
  final WalletService _walletService = WalletService();

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(allWalletsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Ví của tôi'),
        centerTitle: true,
      ),
      body: walletsAsync.when(
        data: (wallets) => _buildWalletList(wallets),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 16),
              Text('Lỗi: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(allWalletsProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddWalletOptions(context),
        icon: const Icon(Icons.add),
        label: const Text('Thêm ví'),
      ),
    );
  }

  Widget _buildWalletList(List<WalletInfo> wallets) {
    if (wallets.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(allWalletsProvider);
        for (final wallet in wallets) {
          ref.invalidate(walletBalanceProvider(wallet.address));
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: wallets.length,
        itemBuilder: (context, index) {
          final wallet = wallets[index];
          return _WalletCard(
            wallet: wallet,
            onTap: () => _selectWallet(wallet),
            onEdit: () => _showEditWalletDialog(wallet),
            onDelete: wallets.length > 1 ? () => _showDeleteConfirmation(wallet) : null,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 56,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chưa có ví nào',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tạo ví mới hoặc nhập ví có sẵn để bắt đầu',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _createNewWallet(),
                child: const Text('Tạo ví mới'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _importWallet(),
                child: const Text('Nhập ví có sẵn'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddWalletOptions(BuildContext context) {
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
            const Text('Thêm ví', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, color: AppTheme.primaryColor),
              ),
              title: const Text('Tạo ví mới'),
              subtitle: const Text('Tạo ví với cụm từ khôi phục mới'),
              onTap: () {
                Navigator.pop(context);
                _createNewWallet();
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.download, color: AppTheme.successColor),
              ),
              title: const Text('Nhập ví có sẵn'),
              subtitle: const Text('Sử dụng cụm từ khôi phục hoặc private key'),
              onTap: () {
                Navigator.pop(context);
                _importWallet();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _createNewWallet() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ref.read(currentWalletProvider.notifier).createWalletQuick();
      
      if (mounted) {
        Navigator.pop(context);
        ref.invalidate(allWalletsProvider);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Đã tạo ví mới!'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _importWallet() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImportWalletScreen()),
    ).then((_) => ref.invalidate(allWalletsProvider));
  }

  Future<void> _selectWallet(WalletInfo wallet) async {
    await _walletService.setCurrentWallet(wallet.address);
    ref.invalidate(currentWalletProvider);
    
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  void _showEditWalletDialog(WalletInfo wallet) {
    final controller = TextEditingController(text: wallet.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi tên ví'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Tên ví', hintText: 'Nhập tên mới'),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await _walletService.renameWallet(wallet.address, newName);
                ref.invalidate(allWalletsProvider);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã đổi tên ví'), backgroundColor: AppTheme.successColor),
                  );
                }
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(WalletInfo wallet) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa ví?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn có chắc muốn xóa ví "${wallet.name}"?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_rounded, color: AppTheme.errorColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hành động này không thể hoàn tác. Hãy đảm bảo bạn đã backup cụm từ khôi phục.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              await _walletService.deleteWalletByAddress(wallet.address);
              ref.invalidate(allWalletsProvider);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa ví')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}

class _WalletCard extends ConsumerWidget {
  final WalletInfo wallet;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _WalletCard({
    required this.wallet,
    required this.onTap,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(walletBalanceProvider(wallet.address));
    final currentWalletAsync = ref.watch(currentWalletProvider);
    final isCurrentWallet = currentWalletAsync.valueOrNull?.address == wallet.address;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: isCurrentWallet ? AppTheme.primaryGradient : null,
        color: isCurrentWallet ? null : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isCurrentWallet ? null : Border.all(color: Theme.of(context).dividerColor),
        boxShadow: isCurrentWallet
            ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: isCurrentWallet ? Colors.white.withOpacity(0.2) : AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.account_balance_wallet_rounded, color: isCurrentWallet ? Colors.white : AppTheme.primaryColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  wallet.name,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isCurrentWallet ? Colors.white : null),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCurrentWallet) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                  child: const Text('Đang dùng', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: wallet.address));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Đã copy địa chỉ'), duration: Duration(seconds: 1)),
                              );
                            },
                            child: Row(
                              children: [
                                Text(
                                  '${wallet.address.substring(0, 8)}...${wallet.address.substring(wallet.address.length - 6)}',
                                  style: TextStyle(fontSize: 13, fontFamily: 'monospace', color: isCurrentWallet ? Colors.white.withOpacity(0.8) : Theme.of(context).textTheme.bodySmall?.color),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.copy_rounded, size: 14, color: isCurrentWallet ? Colors.white.withOpacity(0.8) : Theme.of(context).textTheme.bodySmall?.color),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: isCurrentWallet ? Colors.white : null),
                      onSelected: (value) {
                        if (value == 'edit') onEdit();
                        if (value == 'delete') onDelete?.call();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Đổi tên')])),
                        if (onDelete != null)
                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: AppTheme.errorColor), SizedBox(width: 8), Text('Xóa', style: TextStyle(color: AppTheme.errorColor))])),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrentWallet ? Colors.white.withOpacity(0.1) : Theme.of(context).dividerColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 20, height: 20,
                                  decoration: BoxDecoration(color: isCurrentWallet ? Colors.white.withOpacity(0.2) : AppTheme.primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                                  child: Center(child: Text('E', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isCurrentWallet ? Colors.white : AppTheme.primaryColor))),
                                ),
                                const SizedBox(width: 6),
                                Text('Ethereum', style: TextStyle(fontSize: 12, color: isCurrentWallet ? Colors.white.withOpacity(0.7) : Theme.of(context).textTheme.bodySmall?.color)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            balanceAsync.when(
                              data: (balance) => Text('${balance.toStringAsFixed(4)} ETH', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isCurrentWallet ? Colors.white : null)),
                              loading: () => Container(width: 80, height: 16, decoration: BoxDecoration(color: isCurrentWallet ? Colors.white.withOpacity(0.2) : Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(4))),
                              error: (_, __) => Text('-- ETH', style: TextStyle(fontSize: 14, color: isCurrentWallet ? Colors.white : null)),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: isCurrentWallet ? Colors.white.withOpacity(0.2) : Theme.of(context).dividerColor),
                      Expanded(
                        child: Center(
                          child: Text('+5 mạng khác', style: TextStyle(fontSize: 12, color: isCurrentWallet ? Colors.white.withOpacity(0.7) : Theme.of(context).textTheme.bodySmall?.color)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WalletInfo {
  final String address;
  final String name;
  final DateTime createdAt;

  WalletInfo({required this.address, required this.name, required this.createdAt});

  String get shortAddress => '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
}
