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

class _LockScreenState extends State<LockScreen> with TickerProviderStateMixin {
  final _storageService = SecureStorageService();
  final _biometricService = BiometricAuthService();

  String _pin = '';
  bool _isPasswordSet = false;
  bool _isLoading = true;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String? _errorMessage;
  static const int _pinLength = 4;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    // Анимация масштабирования при появлении
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    // Пульсирующая анимация для иконки
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Анимация тряски для ошибки
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _animationController.forward();
    _checkPasswordStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _checkPasswordStatus() async {
    final isSet = await _storageService.isPasswordSet();
    final biometricEnabled = await _storageService.getBiometricEnabled();
    final biometricAvailable = await _biometricService.canUseBiometrics();

    setState(() {
      _isPasswordSet = isSet;
      _biometricEnabled = biometricEnabled;
      _biometricAvailable = biometricAvailable;
      _isLoading = false;
    });

    // НЕ запускаем биометрию автоматически
  }

  Future<void> _authenticateWithBiometrics() async {
    if (!_biometricEnabled) {
      setState(() {
        _errorMessage = 'Биометрическая аутентификация отключена в настройках';
      });
      return;
    }

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

  void _onNumberPressed(String number) {
    if (_pin.length < _pinLength) {
      setState(() {
        _pin += number;
        _errorMessage = null;
      });

      // Автоматически проверяем/устанавливаем PIN когда введено 4 цифры
      if (_pin.length == _pinLength) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (_isPasswordSet) {
            _verifyPassword();
          } else {
            _setPassword();
          }
        });
      }
    }
  }

  void _onDeletePressed() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _setPassword() async {
    if (_pin.length != _pinLength) {
      setState(() {
        _errorMessage = 'PIN-код должен содержать $_pinLength цифры';
      });
      return;
    }

    await _storageService.setPassword(_pin);

    setState(() {
      _isPasswordSet = true;
      _errorMessage = null;
    });

    _unlockApp();
  }

  Future<void> _verifyPassword() async {
    if (_pin.length != _pinLength) {
      setState(() {
        _errorMessage = 'Введите $_pinLength цифры';
      });
      return;
    }

    final isValid = await _storageService.verifyPassword(_pin);

    if (isValid) {
      _unlockApp();
    } else {
      // Анимация тряски при ошибке
      _shakeController.forward(from: 0);
      setState(() {
        _errorMessage = 'Неверный PIN-код';
        _pin = '';
      });
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
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.deepPurple.shade400,
                Colors.deepPurple.shade700,
                Colors.indigo.shade900,
              ],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ),
        ),
      );
    }

    // Показываем биометрическую кнопку только если:
    // 1. Пароль установлен
    // 2. Биометрия включена в настройках
    // 3. Биометрия доступна на устройстве
    final showBiometric = _isPasswordSet && _biometricEnabled && _biometricAvailable;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade400,
              Colors.deepPurple.shade700,
              Colors.indigo.shade900,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Compact icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.2),
                            blurRadius: 20,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // App title
                    const Text(
                      'CashGuard',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isPasswordSet ? 'Введите PIN-код' : 'Создайте PIN-код',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // PIN indicators
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shakeAnimation.value *
                            ((_shakeController.value * 4).floor().isEven ? 1 : -1), 0),
                          child: child,
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pinLength, (index) {
                          final isFilled = index < _pin.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isFilled ? Colors.white : Colors.white.withValues(alpha: 0.3),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5),
                                width: 2,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Error message
                    if (_errorMessage != null) ...[
                      Container(
                        constraints: const BoxConstraints(maxWidth: 280),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade400.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Number pad
                    Container(
                      constraints: const BoxConstraints(maxWidth: 300),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Rows 1-3
                          for (int row = 0; row < 3; row++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  for (int col = 1; col <= 3; col++)
                                    _buildNumberButton('${row * 3 + col}'),
                                ],
                              ),
                            ),
                          // Last row with biometric, 0, delete
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Biometric button or empty space
                              if (showBiometric)
                                _buildActionButton(
                                  icon: Icons.fingerprint_rounded,
                                  onPressed: _authenticateWithBiometrics,
                                )
                              else
                                const SizedBox(width: 64, height: 64),

                              // 0 button
                              _buildNumberButton('0'),

                              // Delete button
                              _buildActionButton(
                                icon: Icons.backspace_outlined,
                                onPressed: _onDeletePressed,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Security badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_rounded,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Защищено шифрованием',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.2),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          splashColor: Colors.white.withValues(alpha: 0.3),
          highlightColor: Colors.white.withValues(alpha: 0.2),
          onTap: () => _onNumberPressed(number),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.2),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          splashColor: Colors.white.withValues(alpha: 0.3),
          highlightColor: Colors.white.withValues(alpha: 0.2),
          onTap: onPressed,
          child: Center(
            child: Icon(
              icon,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}