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
        appBar: AppBar(
          title: const Text('Mở khóa'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Nhập mã PIN',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                'Nhập mã PIN gồm 6 chữ số để mở khóa ứng dụng',
                style: TextStyle(fontSize: 14, color: Colors.grey),
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
                          color: index < _pinInput.length ? Colors.blue : Colors.grey[300],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Biometric button (if available)
              if (_biometricEnabled && _biometricAvailable) ...[
                ElevatedButton.icon(
                  onPressed: _authenticateBiometric,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Sử dụng vân tay / Face ID'),
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

              // Number Keypad
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
                    // Delete button
                    return _buildDeleteButton();
                  } else if (index == 11) {
                    // Submit button
                    return _buildActionButton(
                      'Mở khóa',
                      _isLoading || _pinInput.length != 6 ? null : _onSubmit,
                      isLoading: _isLoading,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
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
}
