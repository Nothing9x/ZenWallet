import 'package:flutter/material.dart';

import '../../core/constants/app_theme.dart';
import '../../shared/widgets/common_widgets.dart';
import 'create_wallet_screen.dart';
import 'import_wallet_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Ví Crypto An Toàn',
      description: 'Lưu trữ và quản lý tiền mã hóa của bạn một cách an toàn với công nghệ mã hóa tiên tiến.',
    ),
    OnboardingPage(
      icon: Icons.swap_horiz_rounded,
      title: 'Gửi & Nhận Dễ Dàng',
      description: 'Chuyển tiền nhanh chóng với phí thấp nhất. Quét QR để nhận tiền trong tích tắc.',
    ),
    OnboardingPage(
      icon: Icons.security_rounded,
      title: 'Bạn Kiểm Soát',
      description: 'Private key được lưu trữ an toàn trên thiết bị của bạn. Không ai có thể truy cập ngoại trừ bạn.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: () => _navigateToAction(),
                  child: const Text('Bỏ qua'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) => _buildPage(_pages[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) => _buildDot(index)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: _currentPage == _pages.length - 1
                  ? Column(
                      children: [
                        PrimaryButton(
                          text: 'Tạo ví mới',
                          icon: Icons.add_rounded,
                          onPressed: () => _navigateToCreateWallet(),
                        ),
                        const SizedBox(height: 16),
                        SecondaryButton(
                          text: 'Nhập ví có sẵn',
                          icon: Icons.download_rounded,
                          onPressed: () => _navigateToImportWallet(),
                        ),
                      ],
                    )
                  : PrimaryButton(
                      text: 'Tiếp tục',
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(page.icon, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 48),
          Text(
            page.title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: _currentPage == index ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: _currentPage == index
            ? AppTheme.primaryColor
            : AppTheme.primaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  void _navigateToAction() {
    _pageController.animateToPage(
      _pages.length - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _navigateToCreateWallet() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateWalletScreen()),
    );
  }

  void _navigateToImportWallet() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ImportWalletScreen()),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String description;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
  });
}
