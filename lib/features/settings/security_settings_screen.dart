import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_theme.dart';
import '../../core/services/biometric_service.dart';
import '../../shared/widgets/common_widgets.dart';

// Provider for biometric settings
final biometricEnabledProvider = StateNotifierProvider<BiometricSettingsNotifier, bool>((ref) {
  return BiometricSettingsNotifier();
});

class BiometricSettingsNotifier extends StateNotifier<bool> {
  BiometricSettingsNotifier() : super(false) {
    _loadSettings();
  }

  static const _key = 'biometric_enabled';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
    state = enabled;
  }
}

class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  final BiometricService _biometricService = BiometricService();
  
  BiometricStatus _biometricStatus = BiometricStatus.notSupported;
  String _biometricTypeName = 'Sinh trắc học';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
  }

  Future<void> _checkBiometricStatus() async {
    final status = await _biometricService.checkBiometricStatus();
    final typeName = await _biometricService.getBiometricTypeName();
    
    setState(() {
      _biometricStatus = status;
      _biometricTypeName = typeName;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final biometricEnabled = ref.watch(biometricEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảo mật'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Biometric section
                _SectionHeader(title: 'Xác thực sinh trắc học'),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: _getBiometricIcon(),
                      title: _biometricTypeName,
                      subtitle: _getBiometricSubtitle(),
                      trailing: _biometricStatus == BiometricStatus.available
                          ? Switch(
                              value: biometricEnabled,
                              onChanged: (value) => _toggleBiometric(value),
                              activeColor: AppTheme.primaryColor,
                            )
                          : TextButton(
                              onPressed: _biometricStatus == BiometricStatus.notEnrolled
                                  ? () => _showSetupInstructions()
                                  : null,
                              child: Text(
                                _biometricStatus == BiometricStatus.notEnrolled
                                    ? 'Thiết lập'
                                    : 'Không hỗ trợ',
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (biometricEnabled) ...[
                  const InfoBanner(
                    message: 'Xác thực sinh trắc học được bật. Bạn cần xác thực khi mở app và xem seed phrase.',
                    type: InfoBannerType.success,
                  ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 16),

                // Auto-lock section
                _SectionHeader(title: 'Tự động khóa'),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: Icons.timer_outlined,
                      title: 'Thời gian tự động khóa',
                      subtitle: '5 phút',
                      onTap: () => _showAutoLockOptions(),
                    ),
                    const Divider(height: 1),
                    _SettingsTile(
                      icon: Icons.lock_outline,
                      title: 'Khóa khi thoát app',
                      trailing: Switch(
                        value: true,
                        onChanged: (value) {},
                        activeColor: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Transaction security
                _SectionHeader(title: 'Bảo mật giao dịch'),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: Icons.verified_user_outlined,
                      title: 'Xác nhận trước khi gửi',
                      subtitle: 'Luôn hiển thị màn hình xác nhận',
                      trailing: Switch(
                        value: true,
                        onChanged: (value) {},
                        activeColor: AppTheme.primaryColor,
                      ),
                    ),
                    const Divider(height: 1),
                    _SettingsTile(
                      icon: Icons.warning_amber_outlined,
                      title: 'Cảnh báo địa chỉ mới',
                      subtitle: 'Cảnh báo khi gửi đến địa chỉ chưa từng giao dịch',
                      trailing: Switch(
                        value: true,
                        onChanged: (value) {},
                        activeColor: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Privacy section
                _SectionHeader(title: 'Quyền riêng tư'),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: Icons.visibility_off_outlined,
                      title: 'Ẩn số dư',
                      subtitle: 'Ẩn số dư trên màn hình chính',
                      trailing: Switch(
                        value: false,
                        onChanged: (value) {},
                        activeColor: AppTheme.primaryColor,
                      ),
                    ),
                    const Divider(height: 1),
                    _SettingsTile(
                      icon: Icons.screenshot_outlined,
                      title: 'Chặn screenshot',
                      subtitle: 'Ngăn chụp ảnh màn hình app',
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

                // Recovery section
                _SectionHeader(title: 'Khôi phục'),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: Icons.key_outlined,
                      title: 'Xem cụm từ khôi phục',
                      subtitle: 'Sao lưu ví của bạn',
                      onTap: () => _viewSeedPhrase(),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  IconData _getBiometricIcon() {
    if (_biometricTypeName.contains('Face')) {
      return Icons.face;
    }
    return Icons.fingerprint;
  }

  String _getBiometricSubtitle() {
    switch (_biometricStatus) {
      case BiometricStatus.available:
        return 'Mở khóa app bằng $_biometricTypeName';
      case BiometricStatus.notEnrolled:
        return 'Chưa thiết lập $_biometricTypeName trên thiết bị';
      case BiometricStatus.notSupported:
        return 'Thiết bị không hỗ trợ sinh trắc học';
    }
  }

  Future<void> _toggleBiometric(bool enable) async {
    if (enable) {
      // Verify biometric before enabling
      final result = await _biometricService.authenticate(
        reason: 'Xác thực để bật $_biometricTypeName',
      );

      if (result.success) {
        ref.read(biometricEnabledProvider.notifier).setEnabled(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã bật $_biometricTypeName'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } else {
        if (mounted && result.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error!),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } else {
      ref.read(biometricEnabledProvider.notifier).setEnabled(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tắt xác thực sinh trắc học')),
        );
      }
    }
  }

  void _showSetupInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thiết lập sinh trắc học'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Để sử dụng tính năng này, bạn cần thiết lập sinh trắc học trong cài đặt thiết bị:'),
            const SizedBox(height: 16),
            const Text('Android:', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('Settings > Security > Fingerprint / Face unlock'),
            const SizedBox(height: 8),
            const Text('iOS:', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('Settings > Face ID & Passcode / Touch ID & Passcode'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  void _showAutoLockOptions() {
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
              'Thời gian tự động khóa',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _AutoLockOption(label: 'Ngay lập tức', value: 0, selected: false),
            _AutoLockOption(label: '1 phút', value: 1, selected: false),
            _AutoLockOption(label: '5 phút', value: 5, selected: true),
            _AutoLockOption(label: '15 phút', value: 15, selected: false),
            _AutoLockOption(label: '30 phút', value: 30, selected: false),
            _AutoLockOption(label: 'Không bao giờ', value: -1, selected: false),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _viewSeedPhrase() async {
    final biometricEnabled = ref.read(biometricEnabledProvider);
    
    if (biometricEnabled) {
      final result = await _biometricService.authenticateForSensitiveAction(
        reason: 'Xác thực để xem cụm từ khôi phục',
      );
      
      if (!result.success) {
        if (mounted && result.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error!),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }
    }

    // Show seed phrase dialog (implement in settings_screen.dart)
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xem trong Settings > Xem cụm từ khôi phục')),
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
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
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

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primaryColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
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

class _AutoLockOption extends StatelessWidget {
  final String label;
  final int value;
  final bool selected;

  const _AutoLockOption({
    required this.label,
    required this.value,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
          : null,
      onTap: () => Navigator.pop(context),
    );
  }
}
