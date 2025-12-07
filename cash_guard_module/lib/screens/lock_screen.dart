import 'package:flutter/material.dart';
import '../services/secure_storage_service.dart';
import '../services/biometric_auth_service.dart';
import 'user_setup_screen.dart';
import 'main_navigation_screen.dart';
import '../constants/app_theme.dart';

class LockScreen extends StatefulWidget {
  final Function(ThemeMode)? onThemeChanged;

  const LockScreen({super.key, this.onThemeChanged});

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
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

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

    final isValid = await _storageService.checkPassword(_pin);

    if (isValid) {
      _unlockApp();
    } else {
      _shakeController.forward(from: 0);
      setState(() {
        _errorMessage = 'Неверный PIN-код';
        _pin = '';
      });
    }
  }

  Future<void> _unlockApp() async {
    final hasUserData = await _storageService.isUserDataSet();

    if (!mounted) return;

    final screen = hasUserData
        ? MainNavigationScreen(onThemeChanged: widget.onThemeChanged)
        : UserSetupScreen(onThemeChanged: widget.onThemeChanged);

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final showBiometric = _isPasswordSet && _biometricEnabled && _biometricAvailable;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withAlpha(30),
                      border: Border.all(
                        color: AppColors.primary.withAlpha(50),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      size: 50,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'CashGuard',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isPasswordSet ? 'Введите PIN-код' : 'Создайте PIN-код',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          _shakeAnimation.value * ((_shakeController.value * 4).floor().isEven ? 1 : -1),
                          0,
                        ),
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
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFilled ? AppColors.primary : AppColors.background,
                            border: Border.all(
                              color: AppColors.border,
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.accentRed,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                  ],
                  Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Column(
                      children: [
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (showBiometric)
                              _buildActionButton(
                                icon: Icons.fingerprint_rounded,
                                onPressed: _authenticateWithBiometrics,
                              )
                            else
                              const SizedBox(width: 72, height: 72),
                            _buildNumberButton('0'),
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: AppColors.textSecondary,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Защищено шифрованием',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.border, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          splashColor: AppColors.primary.withAlpha(40),
          highlightColor: AppColors.primary.withAlpha(20),
          onTap: () => _onNumberPressed(number),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
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
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          splashColor: AppColors.primary.withAlpha(40),
          highlightColor: AppColors.primary.withAlpha(20),
          onTap: onPressed,
          child: Center(
            child: Icon(
              icon,
              color: AppColors.textSecondary,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}
