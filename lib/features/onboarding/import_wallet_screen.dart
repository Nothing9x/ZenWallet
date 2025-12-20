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
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePrivateKey = true;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhập ví'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Cụm từ khôi phục'),
            Tab(text: 'Private Key'),
          ],
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Theme.of(context).textTheme.bodySmall?.color,
          indicatorColor: AppTheme.primaryColor,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMnemonicTab(),
          _buildPrivateKeyTab(),
        ],
      ),
    );
  }

  Widget _buildMnemonicTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const InfoBanner(
              message: 'Nhập cụm từ khôi phục 12 hoặc 24 từ của bạn, '
                  'các từ cách nhau bởi dấu cách.',
              type: InfoBannerType.info,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _mnemonicController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'word1 word2 word3 ...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập cụm từ khôi phục';
                }
                final words = value.trim().split(RegExp(r'\s+'));
                if (words.length != 12 && words.length != 24) {
                  return 'Cụm từ phải có 12 hoặc 24 từ';
                }
                final walletService = WalletService();
                if (!walletService.validateMnemonic(value.trim())) {
                  return 'Cụm từ không hợp lệ';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 8),
                Text(
                  'Số từ: ${_mnemonicController.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const InfoBanner(
              message: 'Hãy chắc chắn bạn đang ở môi trường an toàn. '
                  'Không ai nên nhìn thấy màn hình của bạn.',
              type: InfoBannerType.warning,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'Nhập ví',
              isLoading: _isLoading,
              onPressed: () => _importFromMnemonic(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivateKeyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InfoBanner(
            message: 'Nhập private key của bạn (bắt đầu bằng 0x hoặc không).',
            type: InfoBannerType.info,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _privateKeyController,
            obscureText: _obscurePrivateKey,
            maxLines: 1,
            decoration: InputDecoration(
              hintText: '0x...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePrivateKey
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() => _obscurePrivateKey = !_obscurePrivateKey);
                },
              ),
            ),
          ),
          const SizedBox(height: 32),
          const InfoBanner(
            message: 'Lưu ý: Khi nhập bằng private key, bạn sẽ không có '
                'cụm từ khôi phục. Hãy đảm bảo lưu trữ private key an toàn.',
            type: InfoBannerType.warning,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            text: 'Nhập ví',
            isLoading: _isLoading,
            onPressed: () => _importFromPrivateKey(),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromMnemonic() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final mnemonic = _mnemonicController.text.trim();
      await ref.read(currentWalletProvider.notifier).importFromMnemonic(mnemonic);

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
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

  Future<void> _importFromPrivateKey() async {
    final privateKey = _privateKeyController.text.trim();
    
    if (privateKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập private key'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(currentWalletProvider.notifier).importFromPrivateKey(privateKey);

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Private key không hợp lệ'),
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
}
