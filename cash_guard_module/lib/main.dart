import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/time_check_wrapper.dart';
import 'services/time_security_service.dart';
import 'services/screen_security_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Отключение поворота экрана - только портретная ориентация
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Включение защиты от скриншотов и записи экрана
  await ScreenSecurityService.enableScreenSecurity();

  final timeSecurityService = TimeSecurityService();
  await timeSecurityService.initialize();

  runApp(const CashGuardApp());
}

class CashGuardApp extends StatelessWidget {
  const CashGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CashGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const TimeCheckWrapper(),
    );
  }
}