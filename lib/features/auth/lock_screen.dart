import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

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

  Future<void> _onSubmit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final stored = await _storage.read(key: 'wallet_pin');
    final pin = _pinController.text.trim();

    await Future.delayed(const Duration(milliseconds: 150));

    if (stored == null) {
      setState(() {
        _error = 'No PIN set';
        _isLoading = false;
      });
      return;
    }

    if (pin == stored) {
      if (mounted) {
        debugPrint('LockScreen: pin match, popping true');
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _error = 'Mã PIN không đúng';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(title: const Text('Mở khóa')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Text('Nhập mã PIN gồm 6 chữ số để mở khóa ứng dụng', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 24),

              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                obscureText: true,
                maxLength: 6,
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), labelText: 'Mã PIN'),
                onSubmitted: (_) => _onSubmit(),
              ),

              const SizedBox(height: 12),
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: _isLoading ? null : _onSubmit,
                child: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Mở khóa'),
              ),

              if (_biometricEnabled && _biometricAvailable) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _authenticateBiometric,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Sử dụng vân tay / Face ID'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
