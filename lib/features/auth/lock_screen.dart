import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/secure_storage_service.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _secureStorage = SecureStorageService();
  final _localAuth = LocalAuthentication();

  String _pinInput = '';
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String? _error;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('biometric_enabled') ?? false;
    bool available = false;
    try {
      available = await _localAuth.canCheckBiometrics && await _localAuth.isDeviceSupported();
    } catch (_) {
      available = false;
    }

    setState(() {
      _biometricEnabled = enabled;
      _biometricAvailable = available;
    });

    if (_biometricEnabled && _biometricAvailable) {
      // Try biometric auth immediately
      WidgetsBinding.instance.addPostFrameCallback((_) => _authenticateBiometric());
    }
  }

  Future<void> _authenticateBiometric() async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Xác thực để mở khóa ứng dụng',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );

      if (ok) {
        if (mounted) {
          debugPrint('LockScreen: biometric auth success, popping true');
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      // ignore and let user enter PIN
    }
  }

  void _addDigit(String digit) {
    setState(() {
      _error = null;
      if (_pinInput.length < 6) {
        _pinInput += digit;
        // Auto-submit when 6 digits entered
        if (_pinInput.length == 6) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _onSubmit();
            }
          });
        }
      }
    });
  }

  void _deleteDigit() {
    setState(() {
      _error = null;
      if (_pinInput.isNotEmpty) {
        _pinInput = _pinInput.substring(0, _pinInput.length - 1);
      }
    });
  }

  Future<void> _onSubmit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final isValid = await _secureStorage.verifyPIN(_pinInput);

    await Future.delayed(const Duration(milliseconds: 150));

    if (!isValid) {
      setState(() {
        _error = 'Mã PIN không đúng';
        _pinInput = '';
        _isLoading = false;
      });
      return;
    }

    if (mounted) {
      debugPrint('LockScreen: pin match, popping true');
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Container(
          color: const Color(0xFFF6F6F8),
          child: SafeArea(
            child: Column(
              children: [
                // Main content
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 16),
                          // App Logo with gradient background
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Large gradient background circle
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFF306ee8).withOpacity(0.12),
                                      const Color(0xFF306ee8).withOpacity(0.04),
                                    ],
                                  ),
                                ),
                              ),
                              // White circle with icon
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.grey[200]!,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.15),
                                      blurRadius: 24,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topRight,
                                          end: Alignment.bottomLeft,
                                          colors: [
                                            const Color(0xFF306ee8).withOpacity(0.1),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.radio_button_unchecked,
                                      size: 48,
                                      color: Color(0xFF306ee8),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          // Title
                          const Text(
                            'Chào mừng trở lại',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0e121b),
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          // Subtitle
                          Text(
                            'Nhập mã PIN 6 số để mở khóa ví',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 40),
                          // PIN indicator dots
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              6,
                              (index) => Container(
                                margin: const EdgeInsets.symmetric(horizontal: 10),
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: index < _pinInput.length
                                        ? const Color(0xFF306ee8)
                                        : Colors.grey[350]!,
                                    width: 2,
                                  ),
                                  color: index < _pinInput.length
                                      ? const Color(0xFF306ee8)
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 24),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 64),
                        ],
                      ),
                    ),
                  ),
                ),
                // Keypad
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      if (index < 9) {
                        // Numbers 1-9
                        final num = index + 1;
                        return _buildNumpadButton(
                          num.toString(),
                          () => _addDigit(num.toString()),
                        );
                      } else if (index == 9) {
                        // Biometric button (face)
                        return _buildBiometricButton();
                      } else if (index == 10) {
                        // 0
                        return _buildNumpadButton('0', () => _addDigit('0'));
                      } else {
                        // Backspace
                        return _buildBackspaceButton();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumpadButton(String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: Colors.grey[200]!,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0e121b),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _biometricAvailable ? _authenticateBiometric : null,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.face,
              size: 32,
              color: const Color(0xFF306ee8),
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
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[800],
          ),
          child: Center(
            child: Icon(
              Icons.backspace,
              size: 28,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
