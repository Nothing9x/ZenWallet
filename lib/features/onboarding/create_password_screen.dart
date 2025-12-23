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
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

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

  Future<void> _onSubmit() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pin.length != 6 || confirm.length != 6) {
      setState(() => _error = 'Mật khẩu phải gồm 6 chữ số');
      return;
    }

    if (pin != confirm) {
      setState(() => _error = 'Mật khẩu xác nhận không khớp');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Save PIN in secure storage
      await _storage.write(key: 'wallet_pin', value: pin);

      // Save biometric preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', _useBiometrics);

      // Proceed depending on flow
      if (widget.isImport) {
        // Go to import screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ImportWalletScreen()),
          );
        }
      } else {
        // Create wallet quick and go to MainScreen (wallet tab)
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

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảo vệ ví'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Tạo mã PIN gồm 6 chữ số để khóa ứng dụng',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            // PIN
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              obscureText: true,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Mã PIN',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Confirm
            TextField(
              controller: _confirmController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              obscureText: true,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Xác nhận mã PIN',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            if (_biometricAvailable) ...[
              SwitchListTile(
                title: const Text('Kích hoạt vân tay/Face ID'),
                value: _useBiometrics,
                onChanged: (v) => setState(() => _useBiometrics = v),
              ),
              const SizedBox(height: 12),
            ],

            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _onSubmit,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(widget.isImport ? 'Tiếp tục để nhập ví' : 'Tạo và tiếp tục'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
