import 'package:cash_guard/screens/lock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/screen_security_service.dart';
import 'services/secure_storage_service.dart';
import 'constants/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Отключение поворота экрана - только портретная ориентация
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Включение защиты от скриншотов и записи экрана
  await ScreenSecurityService.enableScreenSecurity();

  // Load saved theme mode
  final storageService = SecureStorageService();
  final savedThemeMode = await storageService.getThemeMode();

  runApp(CashGuardApp(initialThemeMode: savedThemeMode));
}

class CashGuardApp extends StatefulWidget {
  final String initialThemeMode;

  const CashGuardApp({super.key, required this.initialThemeMode});

  // Global key for accessing app state from anywhere
  static final GlobalKey<CashGuardAppState> appKey = GlobalKey<CashGuardAppState>();

  @override
  State<CashGuardApp> createState() => CashGuardAppState();
}

class CashGuardAppState extends State<CashGuardApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = _parseThemeMode(widget.initialThemeMode);
  }

  ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });

    // Update system UI based on theme
    _updateSystemUI(mode);
  }

  void _updateSystemUI(ThemeMode mode) {
    final isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Update AppColors based on current theme
    final isDark = _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    AppColors.setDarkMode(isDark);

    return MaterialApp(
      key: CashGuardApp.appKey,
      title: 'CashGuard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      // Smooth theme transition animation
      themeAnimationDuration: const Duration(milliseconds: 400),
      themeAnimationCurve: Curves.easeInOut,
      builder: (context, child) {
        // Update AppColors when theme changes
        final brightness = Theme.of(context).brightness;
        AppColors.setDarkMode(brightness == Brightness.dark);

        return GradientBackground(
          child: child ?? const SizedBox(),
        );
      },
      home: LockScreen(
        onThemeChanged: setThemeMode,
      ),
    );
  }
}
