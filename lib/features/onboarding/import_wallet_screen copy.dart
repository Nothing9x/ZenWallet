import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_theme.dart';
import '../../core/providers/wallet_provider.dart';
import '../../core/services/wallet_service.dart';
import '../../shared/widgets/common_widgets.dart';
import '../home/home_screen.dart';

class ImportWalletScreen extends ConsumerStatefulWidget {
  const ImportWalletScreen({super.key});

  @override
  ConsumerState<ImportWalletScreen> createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends ConsumerState<ImportWalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _mnemonicController = TextEditingController();
  final _privateKeyController = TextEditingController();
  
  bool _isLoading = false;
  bool _showPrivateKey = false;
  String? _error;

  final WalletService _walletService = WalletService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mnemonicController.dispose();
    _privateKeyController.dispose();
    super.dispose();
  }

  Future<void> _importFromMnemonic() async {
    final mnemonic = _mnemonicController.text.trim().toLowerCase();
    
    // Validate
    if (mnemonic.isEmpty) {
      setState(() => _error = 'Vui lòng nhập cụm từ khôi phục');
      return;
    }

    final words = mnemonic.split(RegExp(r'\s+'));
    if (words.length != 12 && words.length != 24) {
      setState(() => _error = 'Cụm từ phải có 12 hoặc 24 từ (hiện tại: ${words.length} từ)');
      return;
    }

    if (!_walletService.validateMnemonic(mnemonic)) {
      setState(() => _error = 'Cụm từ không hợp lệ. Vui lòng kiểm tra lại.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(currentWalletProvider.notifier).importFromMnemonic(mnemonic);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _importFromPrivateKey() async {
    final privateKey = _privateKeyController.text.trim();
    
    // Validate
    if (privateKey.isEmpty) {
      setState(() => _error = 'Vui lòng nhập private key');
      return;
    }

    String cleanKey = privateKey;
    if (cleanKey.startsWith('0x')) {
      cleanKey = cleanKey.substring(2);
    }

    if (cleanKey.length != 64) {
      setState(() => _error = 'Private key phải có 64 ký tự hex (hiện tại: ${cleanKey.length})');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(currentWalletProvider.notifier).importFromPrivateKey(privateKey);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhập ví'),
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Cụm từ khôi phục'),
                Tab(text: 'Private Key'),
              ],
              onTap: (_) => setState(() => _error = null),
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMnemonicTab(),
                _buildPrivateKeyTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMnemonicTab() {
    final words = _mnemonicController.text.trim().split(RegExp(r'\s+'));
    final wordCount = _mnemonicController.text.trim().isEmpty ? 0 : words.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InfoBanner(
            message: 'Nhập 12 hoặc 24 từ cách nhau bởi dấu cách',
            type: InfoBannerType.info,
          ),
          const SizedBox(height: 20),

          // Mnemonic input
          TextField(
            controller: _mnemonicController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'abandon ability able about above absent...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste),
                onPressed: () async {
                  // Paste from clipboard
                  // final data = await Clipboard.getData('text/plain');
                  // if (data?.text != null) {
                  //   _mnemonicController.text = data!.text!;
                  // }
                },
              ),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 8),

          // Word count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$wordCount từ',
                style: TextStyle(
                  color: wordCount == 12 || wordCount == 24
                      ? AppTheme.successColor
                      : Theme.of(context).textTheme.bodySmall?.color,
                  fontWeight: wordCount == 12 || wordCount == 24
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              Text(
                'Cần 12 hoặc 24 từ',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Error message
          if (_error != null) ...[
            InfoBanner(
              message: _error!,
              type: InfoBannerType.error,
            ),
            const SizedBox(height: 20),
          ],

          // Import button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _importFromMnemonic,
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
                  : const Text('Nhập ví'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivateKeyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InfoBanner(
            message: 'Nhập private key 64 ký tự (có thể bắt đầu bằng 0x)',
            type: InfoBannerType.info,
          ),
          const SizedBox(height: 20),

          // Private key input
          TextField(
            controller: _privateKeyController,
            obscureText: !_showPrivateKey,
            decoration: InputDecoration(
              hintText: '0x...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(_showPrivateKey ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showPrivateKey = !_showPrivateKey),
                  ),
                  IconButton(
                    icon: const Icon(Icons.content_paste),
                    onPressed: () async {
                      // Paste from clipboard
                    },
                  ),
                ],
              ),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 20),

          // Warning
          const InfoBanner(
            message: 'Ví import bằng private key sẽ không có cụm từ khôi phục. '
                'Đảm bảo bạn đã lưu private key an toàn.',
            type: InfoBannerType.warning,
          ),
          const SizedBox(height: 20),

          // Error message
          if (_error != null) ...[
            InfoBanner(
              message: _error!,
              type: InfoBannerType.error,
            ),
            const SizedBox(height: 20),
          ],

          // Import button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _importFromPrivateKey,
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
                  : const Text('Nhập ví'),
            ),
          ),
        ],
      ),
    );
  }
}
