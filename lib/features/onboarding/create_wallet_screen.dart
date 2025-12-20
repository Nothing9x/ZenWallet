import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_theme.dart';
import '../../core/providers/wallet_provider.dart';
import '../../core/services/wallet_service.dart';
import '../../shared/widgets/common_widgets.dart';
import '../home/home_screen.dart';

class CreateWalletScreen extends ConsumerStatefulWidget {
  const CreateWalletScreen({super.key});

  @override
  ConsumerState<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends ConsumerState<CreateWalletScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  String? _mnemonic;
  List<String> _mnemonicWords = [];
  bool _isLoading = false;
  bool _hasBackedUp = false;
  
  // Verification
  final List<int> _verificationIndices = [];
  final Map<int, String> _verificationAnswers = {};
  
  @override
  void initState() {
    super.initState();
    _generateMnemonic();
  }

  void _generateMnemonic() {
    final walletService = WalletService();
    _mnemonic = walletService.generateMnemonic();
    _mnemonicWords = _mnemonic!.split(' ');
    
    // Generate 3 random indices for verification
    final indices = List.generate(12, (i) => i)..shuffle();
    _verificationIndices.addAll(indices.take(3));
    _verificationIndices.sort();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getStepTitle()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _handleBack,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(),
            
            // Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildWarningStep(),
                  _buildSeedPhraseStep(),
                  _buildVerificationStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Quan trọng';
      case 1:
        return 'Cụm từ khôi phục';
      case 2:
        return 'Xác nhận';
      default:
        return '';
    }
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(3, (index) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: index <= _currentStep
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWarningStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InfoBanner(
            message: 'Cụm từ khôi phục là cách DUY NHẤT để khôi phục ví của bạn. '
                'Hãy ghi lại và giữ ở nơi an toàn!',
            type: InfoBannerType.warning,
          ),
          const SizedBox(height: 32),
          _buildWarningItem(
            icon: Icons.visibility_off_rounded,
            title: 'Không chia sẻ với ai',
            description: 'Bất kỳ ai có cụm từ này đều có thể truy cập ví của bạn.',
          ),
          const SizedBox(height: 16),
          _buildWarningItem(
            icon: Icons.cloud_off_rounded,
            title: 'Không lưu trữ online',
            description: 'Không chụp ảnh, screenshot hoặc lưu vào cloud.',
          ),
          const SizedBox(height: 16),
          _buildWarningItem(
            icon: Icons.edit_note_rounded,
            title: 'Ghi ra giấy',
            description: 'Cách an toàn nhất là ghi ra giấy và cất giữ cẩn thận.',
          ),
          const SizedBox(height: 16),
          _buildWarningItem(
            icon: Icons.support_agent_rounded,
            title: 'Chúng tôi không bao giờ hỏi',
            description: 'VWallet sẽ KHÔNG BAO GIỜ yêu cầu cụm từ khôi phục của bạn.',
          ),
          const SizedBox(height: 32),
          CheckboxListTile(
            value: _hasBackedUp,
            onChanged: (value) {
              setState(() => _hasBackedUp = value ?? false);
            },
            title: const Text(
              'Tôi hiểu rằng nếu mất cụm từ này, tôi sẽ mất quyền truy cập ví',
              style: TextStyle(fontSize: 14),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            text: 'Tiếp tục',
            isEnabled: _hasBackedUp,
            onPressed: () => _nextStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.warningColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.warningColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSeedPhraseStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ghi lại 12 từ bên dưới theo đúng thứ tự:',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _mnemonicWords.length,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(7),
                            bottomLeft: Radius.circular(7),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            _mnemonicWords[index],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _mnemonic!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Đã copy cụm từ khôi phục'),
                      ],
                    ),
                    backgroundColor: AppTheme.successColor,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 20),
              label: const Text('Copy cụm từ'),
            ),
          ),
          const SizedBox(height: 24),
          const InfoBanner(
            message: 'Đảm bảo bạn đã ghi lại cụm từ trước khi tiếp tục. '
                'Bạn sẽ cần xác nhận trong bước tiếp theo.',
            type: InfoBannerType.info,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            text: 'Tôi đã ghi lại',
            onPressed: () => _nextStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationStep() {
    final allAnswered = _verificationIndices.every(
      (index) => _verificationAnswers[index]?.isNotEmpty ?? false,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nhập các từ tương ứng để xác nhận:',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          ...List.generate(_verificationIndices.length, (i) {
            final wordIndex = _verificationIndices[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: CustomTextField(
                label: 'Từ thứ ${wordIndex + 1}',
                hint: 'Nhập từ thứ ${wordIndex + 1}',
                onChanged: (value) {
                  setState(() {
                    _verificationAnswers[wordIndex] = value.trim().toLowerCase();
                  });
                },
              ),
            );
          }),
          const SizedBox(height: 24),
          PrimaryButton(
            text: 'Xác nhận',
            isLoading: _isLoading,
            isEnabled: allAnswered,
            onPressed: () => _verifyAndCreateWallet(),
          ),
        ],
      ),
    );
  }

  void _handleBack() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _nextStep() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep++);
  }

  Future<void> _verifyAndCreateWallet() async {
    // Verify answers
    bool allCorrect = true;
    for (final index in _verificationIndices) {
      if (_verificationAnswers[index] != _mnemonicWords[index]) {
        allCorrect = false;
        break;
      }
    }

    if (!allCorrect) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Một số từ không chính xác. Vui lòng thử lại.'),
            ],
          ),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(currentWalletProvider.notifier).importFromMnemonic(_mnemonic!);
      
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
