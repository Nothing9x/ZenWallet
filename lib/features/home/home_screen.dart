import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_theme.dart';
import '../../core/models/network.dart';
import '../../core/providers/wallet_provider.dart';
import '../../core/services/notification_service.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/backup_reminder_banner.dart';
import '../send/send_screen.dart';
import '../receive/receive_screen.dart';
import '../scan/qr_scanner_screen.dart';
import '../swap/swap_screen.dart';
import '../history/transaction_history_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/backup_wallet_screen.dart';
import '../wallet_list/wallet_list_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();
    await _notificationService.requestPermissions();
    
    final wallet = ref.read(currentWalletProvider).valueOrNull;
    final network = ref.read(selectedNetworkProvider);
    
    if (wallet != null) {
      _notificationService.startMonitoring(
        address: wallet.address,
        network: network,
      );
    }
  }

  @override
  void dispose() {
    _notificationService.stopAllMonitoring();
    super.dispose();
  }

  void _onTabTapped(int index) {
    // Index 2 = Wallets tab -> Navigate to WalletListScreen
    if (index == 2) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WalletListScreen()),
        (route) => false,
      );
      return;
    }
    
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _WalletTab(),
          TransactionHistoryScreen(),
          SizedBox(), // Placeholder for Wallets tab (navigates away)
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Trang chủ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history_rounded),
              label: 'Lịch sử',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Ví',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: 'Cài đặt',
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletTab extends ConsumerWidget {
  const _WalletTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(currentWalletProvider);
    final selectedNetwork = ref.watch(selectedNetworkProvider);
    final balanceAsync = ref.watch(nativeBalanceProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(nativeBalanceProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Wallet selector & Network
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Wallet selector - TAP TO GO TO WALLET LIST
                        walletAsync.when(
                          data: (wallet) => wallet != null
                              ? _WalletSelector(
                                  walletName: wallet.name,
                                  address: wallet.shortAddress,
                                  onTap: () => _navigateToWalletList(context),
                                )
                              : const SizedBox.shrink(),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                        
                        // Network selector
                        _NetworkSelector(
                          network: selectedNetwork,
                          onTap: () => _showNetworkSelector(context, ref),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Backup reminder banner
                    BackupReminderBanner(
                      onBackupPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BackupWalletScreen(),
                        ),
                      ),
                    ),
                    
                    // Balance Card
                    balanceAsync.when(
                      data: (balance) => BalanceCard(
                        balance: balance.displayBalance,
                        symbol: balance.token.symbol,
                        networkName: selectedNetwork.name,
                        onSend: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SendScreen()),
                        ),
                        onReceive: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ReceiveScreen()),
                        ),
                      ),
                      loading: () => _buildLoadingCard(selectedNetwork),
                      error: (e, _) => _buildErrorCard(context, ref, selectedNetwork, e.toString()),
                    ),
                  ],
                ),
              ),
            ),

            // Quick Actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hành động nhanh',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.qr_code_scanner_rounded,
                            label: 'Quét QR',
                            onTap: () async {
                              final result = await Navigator.push<String>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const QRScannerScreen(),
                                ),
                              );
                              
                              if (result != null && context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SendScreen(initialAddress: result),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.swap_horiz_rounded,
                            label: 'Swap',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SwapScreen()),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.add_card_rounded,
                            label: 'Mua',
                            onTap: () => _showBuyOptions(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Assets section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tài sản',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Tính năng sẽ có trong bản cập nhật')),
                            );
                          },
                          child: const Text('+ Thêm token'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Token list
            SliverToBoxAdapter(
              child: balanceAsync.when(
                data: (balance) => _TokenListItem(
                  symbol: balance.token.symbol,
                  name: balance.token.name,
                  balance: balance.displayBalance,
                  iconUrl: balance.token.iconUrl,
                ),
                loading: () => const _TokenListItemSkeleton(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  void _navigateToWalletList(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WalletListScreen()),
      (route) => false,
    );
  }

  Widget _buildLoadingCard(Network network) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              network.name,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Số dư', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            width: 150,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, WidgetRef ref, Network network, String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Không thể tải số dư',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Kiểm tra kết nối mạng và thử lại',
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.invalidate(nativeBalanceProvider),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  void _showNetworkSelector(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _NetworkSelectorSheet(ref: ref),
    );
  }

  void _showBuyOptions(BuildContext context) {
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
              'Mua Crypto',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Chọn sàn để mua crypto với ưu đãi đặc biệt',
              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
            ),
            const SizedBox(height: 24),
            _ExchangeOption(
              name: 'Binance',
              discount: 'Giảm 20% phí giao dịch',
              color: const Color(0xFFF0B90B),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 12),
            _ExchangeOption(
              name: 'OKX',
              discount: 'Bonus lên đến \$50',
              color: const Color(0xFF00DC82),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 12),
            _ExchangeOption(
              name: 'MEXC',
              discount: '0% phí spot trading',
              color: const Color(0xFF00B897),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Link liên kết. Bạn được ưu đãi, chúng tôi nhận hoa hồng nhỏ.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// Wallet Selector Widget - Tap to go to WalletListScreen
class _WalletSelector extends StatelessWidget {
  final String walletName;
  final String address;
  final VoidCallback onTap;

  const _WalletSelector({
    required this.walletName,
    required this.address,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  walletName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  address,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withOpacity(0.8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkSelector extends StatelessWidget {
  final Network network;
  final VoidCallback onTap;

  const _NetworkSelector({required this.network, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  network.symbol.substring(0, 1),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              network.symbol,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 28),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TokenListItem extends StatelessWidget {
  final String symbol;
  final String name;
  final String balance;
  final String? iconUrl;

  const _TokenListItem({
    required this.symbol,
    required this.name,
    required this.balance,
    this.iconUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                symbol.substring(0, symbol.length > 3 ? 3 : symbol.length),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(symbol, style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(balance, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Text(symbol, style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TokenListItemSkeleton extends StatelessWidget {
  const _TokenListItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: Theme.of(context).dividerColor, shape: BoxShape.circle)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 100, height: 16, decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 4),
                Container(width: 60, height: 14, decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkSelectorSheet extends StatelessWidget {
  final WidgetRef ref;
  const _NetworkSelectorSheet({required this.ref});

  @override
  Widget build(BuildContext context) {
    final networks = ref.watch(allNetworksProvider);
    final selectedNetwork = ref.watch(selectedNetworkProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chọn mạng', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...networks.map((network) => ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Center(child: Text(network.symbol.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor))),
            ),
            title: Text(network.name),
            subtitle: Text(network.symbol),
            trailing: selectedNetwork == network ? const Icon(Icons.check_circle, color: AppTheme.primaryColor) : null,
            onTap: () {
              ref.read(selectedNetworkProvider.notifier).state = network;
              Navigator.pop(context);
            },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ExchangeOption extends StatelessWidget {
  final String name;
  final String discount;
  final Color color;
  final VoidCallback onTap;

  const _ExchangeOption({required this.name, required this.discount, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(name[0], style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    Text(discount, style: const TextStyle(fontSize: 14, color: AppTheme.successColor)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}