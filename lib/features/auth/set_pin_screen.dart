import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../home/main_screen.dart';

class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
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
      final can = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      setState(() => _biometricAvailable = can && supported);
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
      await _storage.write(key: 'wallet_pin', value: pin);
      // read back to verify
      final stored = await _storage.read(key: 'wallet_pin');
      debugPrint('🔒 SetPinScreen: wrote pin, readBack=${stored != null}');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', _useBiometrics);

      if (mounted) {
        debugPrint('🔒 SetPinScreen: wrote pin, navigating to MainScreen');
        await Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const MainScreen(initialTab: 0),
            settings: const RouteSettings(name: 'MainScreen'),
          ),
          (route) => false,
        );
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
      appBar: AppBar(title: const Text('Thiết lập mã PIN')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Tạo mã PIN gồm 6 chữ số để bảo vệ ứng dụng', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              obscureText: true,
              maxLength: 6,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), labelText: 'Mã PIN'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              obscureText: true,
              maxLength: 6,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), labelText: 'Xác nhận mã PIN'),
            ),
            const SizedBox(height: 12),
            if (_biometricAvailable) SwitchListTile(
              title: const Text('Kích hoạt vân tay/Face ID'),
              value: _useBiometrics,
              onChanged: (v) => setState(() => _useBiometrics = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _onSubmit,
              child: _isLoading ? const SizedBox(width:24,height:24,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2)) : const Text('Lưu mã PIN'),
            ),
          ],
        ),
      ),
    );
  }
}
