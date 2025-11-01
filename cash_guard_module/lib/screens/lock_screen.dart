import 'package:flutter/material.dart';
import '../services/secure_storage_service.dart';
import '../services/biometric_auth_service.dart';
import 'user_setup_screen.dart';
import 'home_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final _storageService = SecureStorageService();
  final _biometricService = BiometricAuthService();

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
    final isSet = await _storageService.isPasswordSet();
    setState(() {
      _isPasswordSet = isSet;
      _isLoading = false;
    });

    // Автоматически показываем биометрию при запуске, если пароль установлен
    if (_isPasswordSet) {
      await _authenticateWithBiometrics();
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    final errorMessage = await _biometricService.getBiometricErrorMessage();
    if (errorMessage != null) {
      setState(() {
        _errorMessage = errorMessage;
      });
      return;
    }

    final authenticated = await _biometricService.authenticate();
    if (authenticated) {
      _unlockApp();
    } else {
      setState(() {
        _errorMessage = 'Биометрическая аутентификация не прошла';
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

    await _storageService.setPassword(_passwordController.text);

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

    final isValid = await _storageService.verifyPassword(_passwordController.text);

    if (isValid) {
      _unlockApp();
    } else {
      setState(() {
        _errorMessage = 'Неверный пароль';
      });
      _passwordController.clear();
    }
  }

  Future<void> _unlockApp() async {
    // Проверяем, есть ли данные пользователя
    final hasUserData = await _storageService.isUserDataSet();

    if (!mounted) return;

    if (hasUserData) {
      // Если данные есть, идем на главный экран
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );
    } else {
      // Если данных нет, идем на экран настройки
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const UserSetupScreen(),
        ),
      );
    }
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
                    'CashGuard',
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