import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_theme.dart';
import '../../core/providers/wallet_provider.dart';
import '../../core/services/wallet_service.dart';
import '../../core/services/biometric_service.dart';
import '../../shared/widgets/common_widgets.dart';

class BackupWalletScreen extends ConsumerStatefulWidget {
  const BackupWalletScreen({super.key});

  @override
  ConsumerState<BackupWalletScreen> createState() => _BackupWalletScreenState();
}

class _BackupWalletScreenState extends ConsumerState<BackupWalletScreen> {
  final WalletService _walletService = WalletService();
  final BiometricService _biometricService = BiometricService();
  
  bool _isAuthenticated = false;
  bool _isLoading = true;
  bool _seedRevealed = false;
  String? _mnemonic;
  String? _error;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    setState(() => _isLoading = true);

    try {
      // Check if biometrics available
      final status = await _biometricService.checkBiometricStatus();
      
      if (status == BiometricStatus.available) {
        final result = await _biometricService.authenticate(
          reason: 'Xác thực để xem cụm từ khôi phục',
        );
        
        if (!result.success) {
          setState(() {
            _isLoading = false;
            _error = result.error ?? 'Xác thực thất bại';
          });
          return;
        }
      }

      // Load mnemonic
      final mnemonic = await _walletService.getMnemonic();
      
      setState(() {
        _isAuthenticated = true;
        _mnemonic = mnemonic;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _markAsBackedUp() async {
    await ref.read(backupStatusProvider.notifier).setBackedUp(true);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Đã đánh dấu ví đã backup!'),
            ],
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup ví'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _isAuthenticated
                  ? _buildBackupContent()
                  : _buildAuthRequired(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _authenticate,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthRequired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 64,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'Cần xác thực',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Xác thực để xem cụm từ khôi phục',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _authenticate,
              child: const Text('Xác thực'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupContent() {
    if (_mnemonic == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.key_off_rounded,
                size: 64,
                color: AppTheme.warningColor,
              ),
              const SizedBox(height: 16),
              const Text(
                'Không có cụm từ khôi phục',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ví này được import bằng private key nên không có cụm từ khôi phục.\n\nHãy đảm bảo bạn đã lưu private key an toàn.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đã hiểu'),
              ),
            ],
          ),
        ),
      );
    }

    final words = _mnemonic!.split(' ');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning banner
          const InfoBanner(
            message: 'KHÔNG BAO GIỜ chia sẻ cụm từ này với bất kỳ ai. '
                'Ai có cụm từ này có thể truy cập và lấy toàn bộ tài sản của bạn.',
            type: InfoBannerType.error,
          ),
          const SizedBox(height: 24),

          // Instructions
          const Text(
            'Cụm từ khôi phục',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Viết ra giấy và cất giữ nơi an toàn. Không chụp ảnh hoặc lưu trên điện thoại.',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 24),

          // Reveal button or seed phrase
          if (!_seedRevealed) ...[
            Center(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.visibility_off_rounded,
                          size: 48,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Cụm từ đang ẩn',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Đảm bảo không ai nhìn thấy màn hình',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() => _seedRevealed = true),
                      icon: const Icon(Icons.visibility_rounded),
                      label: const Text('Hiện cụm từ khôi phục'),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Seed phrase grid
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: words.length,
                    itemBuilder: (context, index) {
                      return Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                words[index],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Copy button
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _mnemonic!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã copy cụm từ khôi phục'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Hide button
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _seedRevealed = false),
                icon: const Icon(Icons.visibility_off_rounded, size: 18),
                label: const Text('Ẩn cụm từ'),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Confirm backup button
          const InfoBanner(
            message: 'Đã viết ra giấy và cất giữ an toàn?',
            type: InfoBannerType.info,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _markAsBackedUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Tôi đã backup xong'),
            ),
          ),
        ],
      ),
    );
  }
}
