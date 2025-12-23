import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/providers/wallet_provider.dart';
import '../home/main_screen.dart';
import 'import_wallet_screen.dart';

class CreatePasswordScreen extends ConsumerStatefulWidget {
  final bool isImport;
  const CreatePasswordScreen({super.key, required this.isImport});

  @override
  ConsumerState<CreatePasswordScreen> createState() => _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends ConsumerState<CreatePasswordScreen> {
  final _storage = const FlutterSecureStorage();
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
      appBar: AppBar(
        title: const Text('Bảo vệ ví'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Step indicator
            Text(
              displayText,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              _isConfirming ? 'Nhập lại mã PIN để xác nhận' : 'Tạo mã PIN gồm 6 chữ số để khóa ứng dụng',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // PIN Display with dots
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  6,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index < currentPin.length ? Colors.blue : Colors.grey[300],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Biometric option (only on first PIN entry, below PIN dots)
            if (!_isConfirming && _biometricAvailable) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kích hoạt vân tay/Face ID',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Mở khóa nhanh hơn với sinh trắc học',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    if (_useBiometrics)
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _biometricAvailable && !_useBiometrics
                            ? _authenticateBiometric
                            : null,
                        icon: const Icon(Icons.fingerprint, size: 18),
                        label: const Text('Kích hoạt'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],

            // Number Keypad (full width)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                if (index < 9) {
                  // Numbers 1-9
                  final num = index + 1;
                  return _buildNumpadButton(num.toString(), () => _addDigit(num.toString()));
                } else if (index == 9) {
                  // 0
                  return _buildNumpadButton('0', () => _addDigit('0'));
                } else if (index == 10) {
                  // Delete button (same for both screens)
                  return _buildDeleteButton();
                } else if (index == 11) {
                  // Submit or Next button
                  if (_isConfirming) {
                    return _buildActionButton(
                      widget.isImport ? 'Tiếp tục' : 'Tạo ví',
                      _isLoading || _confirmInput.length != 6
                          ? null
                          : _onSubmit,
                      isLoading: _isLoading,
                    );
                  } else {
                    return _buildActionButton(
                      'Tiếp tục',
                      _pinInput.length == 6 ? () {
                        setState(() => _isConfirming = true);
                      } : null,
                    );
                  }
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpadButton(String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _deleteDigit,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.red[200]!),
            borderRadius: BorderRadius.circular(10),
            color: Colors.red[50],
          ),
          child: Center(
            child: Icon(
              Icons.backspace_outlined,
              color: Colors.red,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback? onTap, {bool isLoading = false}) {
    final isEnabled = onTap != null && !isLoading;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isEnabled ? Colors.blue : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(10),
            color: isEnabled ? Colors.blue : Colors.grey[100],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isEnabled ? Colors.white : Colors.grey,
                    ),
                    textAlign: TextAlign.center,
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
      await _storage.write(key: 'wallet_pin', value: _pinInput);

      // Save biometric preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', _useBiometrics);

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
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
