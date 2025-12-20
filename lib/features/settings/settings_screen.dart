import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_theme.dart';
import '../../core/providers/wallet_provider.dart';
import '../../core/services/wallet_service.dart';
import '../../shared/widgets/common_widgets.dart';
import '../onboarding/onboarding_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(currentWalletProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Wallet section
            _SectionHeader(title: 'Ví'),
            _SettingsCard(
              children: [
                walletAsync.when(
                  data: (wallet) => _SettingsTile(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Địa chỉ ví',
                    subtitle: wallet?.shortAddress ?? 'Chưa có ví',
                    onTap: () {},
                  ),
                  loading: () => const _SettingsTile(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Địa chỉ ví',
                    subtitle: 'Đang tải...',
                  ),
                  error: (_, __) => const _SettingsTile(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Địa chỉ ví',
                    subtitle: 'Lỗi',
                  ),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.key_rounded,
                  title: 'Xem cụm từ khôi phục',
                  subtitle: 'Sao lưu ví của bạn',
                  onTap: () => _showSeedPhrase(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Security section
            _SectionHeader(title: 'Bảo mật'),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.fingerprint_rounded,
                  title: 'Xác thực sinh trắc học',
                  subtitle: 'Mở khóa bằng vân tay/Face ID',
                  trailing: Switch(
                    value: false,
                    onChanged: (value) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tính năng sẽ có trong bản cập nhật')),
                      );
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // About section
            _SectionHeader(title: 'Thông tin'),
            _SettingsCard(
              children: [
                const _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: 'Phiên bản',
                  subtitle: '1.0.0',
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Trợ giúp & Hỗ trợ',
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Danger zone
            _SectionHeader(title: 'Vùng nguy hiểm'),
            _SettingsCard(
              borderColor: AppTheme.errorColor.withOpacity(0.3),
              children: [
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Đăng xuất',
                  subtitle: 'Xóa ví khỏi thiết bị này',
                  iconColor: AppTheme.errorColor,
                  titleColor: AppTheme.errorColor,
                  onTap: () => _showLogoutDialog(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Footer
            Center(
              child: Column(
                children: [
                  Text(
                    'VWallet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Made with ❤️ in Vietnam',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showSeedPhrase(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cảnh báo'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InfoBanner(
              message: 'Cụm từ khôi phục cho phép bất kỳ ai truy cập ví của bạn!',
              type: InfoBannerType.warning,
            ),
            SizedBox(height: 16),
            Text('Bạn có chắc muốn xem cụm từ khôi phục?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningColor),
            child: const Text('Xem'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final mnemonic = await WalletService().getMnemonic();
    
    if (mnemonic != null && context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cụm từ khôi phục'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const InfoBanner(
                  message: 'Ghi lại và lưu ở nơi an toàn!',
                  type: InfoBannerType.warning,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: mnemonic.split(' ').asMap().entries.map((entry) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${entry.key + 1}. ${entry.value}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ví được nhập bằng private key, không có cụm từ khôi phục'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
    }
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa ví'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InfoBanner(
              message: 'Đảm bảo bạn đã sao lưu cụm từ khôi phục trước khi xóa!',
              type: InfoBannerType.error,
            ),
            SizedBox(height: 16),
            Text('Bạn có chắc muốn xóa ví?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Xóa ví'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(currentWalletProvider.notifier).deleteWallet();
    
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final Color? borderColor;

  const _SettingsCard({required this.children, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? Theme.of(context).dividerColor),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (iconColor ?? AppTheme.primaryColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? AppTheme.primaryColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: titleColor),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color))
          : null,
      trailing: trailing ?? (onTap != null
          ? Icon(Icons.chevron_right_rounded, color: Theme.of(context).textTheme.bodySmall?.color)
          : null),
      onTap: onTap,
    );
  }
}
