import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_theme.dart';
import 'core/services/wallet_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'features/auth/lock_screen.dart';
import 'features/home/main_screen.dart';
import 'features/wallet_list/wallet_list_screen.dart';
import 'features/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: ZenWalletApp()));
}

class ZenWalletApp extends StatelessWidget {
  const ZenWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZenWallet',
      navigatorObservers: [LoggingObserver()],
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AppEntryPoint(),
    );
  }
}

/// Simple observer to log route changes for debugging navigation issues
class LoggingObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    debugPrint('Navigator: didPush ${route.settings.name ?? route.runtimeType}');
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    debugPrint('Navigator: didPop ${route.settings.name ?? route.runtimeType}');
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    debugPrint('Navigator: didReplace ${oldRoute?.settings.name ?? oldRoute?.runtimeType} -> ${newRoute?.settings.name ?? newRoute?.runtimeType}');
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> with WidgetsBindingObserver {
  final WalletService _walletService = WalletService();
  final _secureStorage = const FlutterSecureStorage();
  bool _isLoading = true;
  bool _hasWallet = false;
  DateTime? _pausedAt;
  bool _lockShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkWalletStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('lifecycle: $state at ${DateTime.now()}');
    // Record the time app moved away. Only set on `paused` to avoid
    // transient `inactive` events resetting the timestamp.
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      debugPrint('🔒 recorded pausedAt=$_pausedAt');
    }

    if (state == AppLifecycleState.resumed) {
      _handleResume();
    }
  }

  Future<void> _handleResume() async {
    try {
      // If no PIN saved, no lock
      final pin = await _secureStorage.read(key: 'wallet_pin');
      debugPrint('🔒 handleResume: pin present=${pin != null} _lockShowing=$_lockShowing');
      if (pin == null) return;

      final paused = _pausedAt;
      if (paused == null) {
        debugPrint('🔒 handleResume: pausedAt is null, skipping lock');
        return;
      }

      final diff = DateTime.now().difference(paused);
      // Debug info to help diagnose lifecycle timing issues
      debugPrint('🔒 handleResume: pausedAt=$paused now=${DateTime.now()} diff=${diff.inSeconds}s');
      if (diff.inSeconds < 60) {
        debugPrint('🔒 handleResume: diff < 60s, skipping lock');
        return; // less than 1 minute -> no lock
      }

      // Show lock screen if not already shown
      if (_lockShowing) {
        debugPrint('🔒 handleResume: lock already showing, abort');
        return;
      }
      _lockShowing = true;

      // push LockScreen on root navigator and wait for success or failure
      if (!mounted) return;
      debugPrint('🔒 handleResume: pushing LockScreen');
      await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
        builder: (_) => const LockScreen(),
        settings: const RouteSettings(name: 'LockScreen'),
      ));
      debugPrint('🔒 handleResume: LockScreen returned');

      // After successful unlock, ensure MainScreen is shown when a wallet exists
      if (_hasWallet) {
        debugPrint('🔒 handleResume: navigating to MainScreen (wallet tab)');
        await Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const MainScreen(initialTab: 0),
            settings: const RouteSettings(name: 'MainScreen'),
          ),
          (route) => false,
        );
      }

      _lockShowing = false;
    } catch (_) {
      _lockShowing = false;
    }
  }

  Future<void> _checkWalletStatus() async {
    try {
      final wallets = await _walletService.getAllWallets();
      setState(() {
        _hasWallet = wallets.isNotEmpty;
        _isLoading = false;
      });

      // After UI settles, if a PIN exists show the LockScreen on startup
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowStartupLock());
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasWallet = false;
      });
    }
  }

  Future<void> _maybeShowStartupLock() async {
    try {
      if (!mounted) return;
      // Only show if wallet exists and not already showing lock
      if (!_hasWallet || _lockShowing) return;

      final pin = await _secureStorage.read(key: 'wallet_pin');
      debugPrint('🔒 startup: pin present=${pin != null}');
      if (pin == null) return;

      _lockShowing = true;
      await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
        builder: (_) => const LockScreen(),
        settings: const RouteSettings(name: 'LockScreen'),
      ));

      // After startup unlock, navigate to MainScreen so user always lands on main tab
      if (_hasWallet) {
        debugPrint('🔒 startup: navigating to MainScreen (wallet tab) after unlock');
        await Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const MainScreen(initialTab: 0),
            settings: const RouteSettings(name: 'MainScreen'),
          ),
          (route) => false,
        );
      }

      _lockShowing = false;
    } catch (_) {
      _lockShowing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    // No wallet exists -> Show onboarding
    if (!_hasWallet) {
      return const OnboardingScreen();
    }

    // Has wallets -> Show MainScreen (landing on WalletListTab)
    return const MainScreen(initialTab: 0);
  }
}
