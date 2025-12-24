import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/providers/wallet_provider.dart';
import '../../core/services/secure_storage_service.dart';
import '../home/main_screen.dart';
import 'import_wallet_screen.dart';

class CreatePasswordScreen extends ConsumerStatefulWidget {
  final bool isImport;
  const CreatePasswordScreen({super.key, required this.isImport});

  @override
  ConsumerState<CreatePasswordScreen> createState() => _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends ConsumerState<CreatePasswordScreen> {
  final _secureStorage = SecureStorageService();
  final _localAuth = LocalAuthentication();

  String _pinInput = '';
  String _confirmInput = '';
  bool _isConfirming = false; // true = confirming, false = entering first PIN
  bool _useBiometrics = false;
  bool _biometricAvailable = false;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      setState(() => _biometricAvailable = canCheck && isSupported);
    } catch (_) {
      setState(() => _biometricAvailable = false);
    }
  }

  void _addDigit(String digit) {
    setState(() {
      _error = null;
      if (!_isConfirming) {
        // Entering first PIN
        if (_pinInput.length < 6) {
          _pinInput += digit;
          // Auto-proceed to confirmation after 6 digits
          if (_pinInput.length == 6) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) setState(() => _isConfirming = true);
            });
          }
        }
      } else {
        // Confirming PIN
        if (_confirmInput.length < 6) {
          _confirmInput += digit;
        }
      }
    });
  }

  void _deleteDigit() {
    setState(() {
      _error = null;
      if (!_isConfirming) {
        if (_pinInput.isNotEmpty) {
          _pinInput = _pinInput.substring(0, _pinInput.length - 1);
        }
      } else {
        if (_confirmInput.isNotEmpty) {
          _confirmInput = _confirmInput.substring(0, _confirmInput.length - 1);
        }
      }
    });
  }

  Future<void> _authenticateBiometric() async {
    try {
      debugPrint('🔒 Starting biometric auth...');
      final ok = await _localAuth.authenticate(
        localizedReason: 'Xác thực để kích hoạt vân tay/Face ID',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      debugPrint('🔒 Biometric auth result: $ok');
      if (ok && mounted) {
        setState(() => _useBiometrics = true);
        debugPrint('🔒 Biometric enabled!');
      }
    } catch (e) {
      debugPrint('❌ Biometric auth error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xác thực sinh trắc học thất bại: $e')),
        );
      }
    }
  }


  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _isConfirming ? _confirmInput : _pinInput;
    final displayText = _isConfirming ? 'Xác nhận mã PIN' : 'Tạo mã PIN';

    return Scaffold(
      body: Container(
        color: const Color(0xFFF6F6F8),
        child: SafeArea(
          child: Column(
            children: [
              // Header with back button
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 24, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0e121b)),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    ),
                    const Expanded(
                      child: Text(
                        'Zen Wallet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0e121b),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              // Main content
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        // Title
                        Text(
                          displayText,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0e121b),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        // Subtitle
                        Text(
                          _isConfirming ? 'Nhập lại mã PIN để xác nhận' : 'Thiết lập mã PIN 6 số để bảo vệ ví',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        // PIN indicator dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            6,
                            (index) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: index < currentPin.length
                                      ? const Color(0xFF306ee8)
                                      : Colors.grey[350]!,
                                  width: 2,
                                ),
                                color: index < currentPin.length
                                    ? const Color(0xFF306ee8)
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 20),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Biometric option
                        if (!_isConfirming && _biometricAvailable) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey[200]!),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.05),
                                  blurRadius: 8,
                                )
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFF306ee8).withOpacity(0.1),
                                        ),
                                        child: const Icon(
                                          Icons.face,
                                          color: Color(0xFF306ee8),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Đăng nhập bằng FaceID',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: Color(0xFF0e121b),
                                              ),
                                            ),
                                            Text(
                                              'Tiện lợi & Bảo mật',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 44,
                                  height: 24,
                                  child: Switch(
                                    value: _useBiometrics,
                                    onChanged: (value) {
                                      if (value) {
                                        _authenticateBiometric();
                                      } else {
                                        setState(() => _useBiometrics = false);
                                      }
                                    },
                                    activeColor: const Color(0xFF306ee8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // Keypad
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 24,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    if (index < 9) {
                      final num = index + 1;
                      return _buildNumpadButton(num.toString(), () => _addDigit(num.toString()));
                    } else if (index == 9) {
                      return const SizedBox.shrink();
                    } else if (index == 10) {
                      return _buildNumpadButton('0', () => _addDigit('0'));
                    } else {
                      return _buildBackspaceButton();
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Bottom button and disclaimer
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading || currentPin.length != 6 ? null : _confirmOrSubmit,
                        icon: const Icon(Icons.arrow_forward, size: 20),
                        label: const Text('Xác nhận'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF306ee8),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_user, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Zen Wallet không lưu trữ mã PIN của bạn.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmOrSubmit() async {
    if (!_isConfirming) {
      // Move to confirmation screen
      setState(() => _isConfirming = true);
      _confirmInput = '';
    } else {
      // Submit
      await _onSubmit();
    }
  }

  Widget _buildNumpadButton(String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0e121b),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _deleteDigit,
        borderRadius: BorderRadius.circular(50),
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0e121b),
            ),
            child: const Icon(
              Icons.backspace,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onSubmit() async {
    if (_pinInput != _confirmInput) {
      setState(() => _error = 'Mã PIN không khớp');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Save PIN in secure storage
      debugPrint('💾 Saving PIN to secure storage (length=${_pinInput.length})');
      await _secureStorage.savePIN(_pinInput);
      
      // Verify PIN was saved
      final verify = await _secureStorage.getPIN();
      debugPrint('✅ PIN saved and verified: ${verify != null && verify == _pinInput}');
      
      if (verify == null || verify != _pinInput) {
        debugPrint('❌ PIN verification failed!');
        setState(() {
          _error = 'Lỗi lưu mã PIN, vui lòng thử lại';
          _isLoading = false;
        });
        return;
      }

      // Save biometric preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', _useBiometrics);
      debugPrint('💾 Biometric preference saved: $_useBiometrics');

      if (widget.isImport) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ImportWalletScreen()),
          );
        }
      } else {
        await ref.read(currentWalletProvider.notifier).createWalletQuick();
        if (mounted) {
          debugPrint('CreatePasswordScreen: wallet created, navigating to MainScreen');
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const MainScreen(initialTab: 0),
              settings: const RouteSettings(name: 'MainScreen'),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error in _onSubmit: $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
