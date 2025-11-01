import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
// CashGuard
void main() {
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
      home: const LockScreen(),
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({Key? key}) : super(key: key);

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  bool _isPasswordSet = false;
  bool _isLoading = true;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkPasswordStatus();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkPasswordStatus() async {
    final hashedPassword = await _secureStorage.read(key: 'user_password');
    setState(() {
      _isPasswordSet = hashedPassword != null;
      _isLoading = false;
    });

    // Автоматически показываем биометрию при запуске, если пароль уже установлен
    if (_isPasswordSet) {
      await _authenticateWithBiometrics();
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

      if (!canAuthenticate) {
        setState(() {
          _errorMessage = 'Биометрия недоступна на этом устройстве';
        });
        return;
      }

      final List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();

      if (availableBiometrics.isEmpty) {
        setState(() {
          _errorMessage = 'Биометрия не настроена на устройстве';
        });
        return;
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Подтвердите вход с помощью биометрии',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (didAuthenticate) {
        _unlockApp();
      } else {
        setState(() {
          _errorMessage = 'Биометрическая аутентификация не прошла';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка биометрии: ${e.toString()}';
      });
    }
  }

  Future<void> _setPassword() async {
    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Пожалуйста, введите пароль';
      });
      return;
    }

    if (_passwordController.text.length < 4) {
      setState(() {
        _errorMessage = 'Пароль должен содержать минимум 4 символа';
      });
      return;
    }

    final hashedPassword = _hashPassword(_passwordController.text);
    await _secureStorage.write(key: 'user_password', value: hashedPassword);

    setState(() {
      _isPasswordSet = true;
      _errorMessage = null;
    });

    _unlockApp();
  }

  Future<void> _verifyPassword() async {
    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Пожалуйста, введите пароль';
      });
      return;
    }

    final storedHash = await _secureStorage.read(key: 'user_password');
    final inputHash = _hashPassword(_passwordController.text);

    if (storedHash == inputHash) {
      _unlockApp();
    } else {
      setState(() {
        _errorMessage = 'Неверный пароль';
      });
      _passwordController.clear();
    }
  }

  void _unlockApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade400,
              Colors.blue.shade800,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    size: 100,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'SecureVault',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isPasswordSet ? 'Добро пожаловать!' : 'Создайте пароль',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: _isPasswordSet ? 'Введите пароль' : 'Создайте пароль',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onSubmitted: (_) {
                            if (_isPasswordSet) {
                              _verifyPassword();
                            } else {
                              _setPassword();
                            }
                          },
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_isPasswordSet) {
                                _verifyPassword();
                              } else {
                                _setPassword();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _isPasswordSet ? 'Войти' : 'Установить пароль',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        if (_isPasswordSet) ...[
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: _authenticateWithBiometrics,
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Войти с биометрией'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  Future<void> _resetPassword(BuildContext context) async {
    const secureStorage = FlutterSecureStorage();
    await secureStorage.delete(key: 'user_password');

    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const LockScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SecureVault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_reset),
            tooltip: 'Сбросить пароль',
            onPressed: () => _resetPassword(context),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 100,
              color: Colors.green.shade400,
            ),
            const SizedBox(height: 20),
            const Text(
              'Добро пожаловать!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Вы успешно вошли в приложение',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Здесь будет ваш защищенный контент',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}