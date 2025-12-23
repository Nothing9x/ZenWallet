import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_theme.dart';
import '../wallet_list/wallet_list_screen.dart';
import '../history/transaction_history_screen.dart';
import '../settings/settings_screen.dart';
import 'wallet_detail_tab.dart';

/// Main screen with bottom navigation
/// Tab 0: Trang chủ (WalletListScreen)
/// Tab 1: Ví (Chi tiết ví đang chọn)
/// Tab 2: Lịch sử
/// Tab 3: Cài đặt
class MainScreen extends ConsumerStatefulWidget {
  final int initialTab;
  
  const MainScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    debugPrint('MainScreen:init initialTab=$_currentIndex');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('MainScreen:build currentIndex=$_currentIndex');
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          WalletListTab(),      // Tab 0: Trang chủ - Danh sách ví
          WalletDetailTab(),    // Tab 1: Ví - Chi tiết ví đang chọn
          TransactionHistoryScreen(), // Tab 2: Lịch sử
          SettingsScreen(),     // Tab 3: Cài đặt
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
          onTap: (index) => setState(() {
                _currentIndex = index;
                debugPrint('MainScreen:onTap -> tab=$_currentIndex');
              }),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Trang chủ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Ví',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history_rounded),
              label: 'Lịch sử',
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

/// WalletListTab - embedded version without its own navigation
class WalletListTab extends ConsumerWidget {
  const WalletListTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const WalletListContent();
  }
}
