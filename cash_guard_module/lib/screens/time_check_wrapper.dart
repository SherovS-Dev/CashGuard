import 'package:flutter/material.dart';
import '../services/time_security_service.dart';
import 'lock_screen.dart';
import '../widgets/time_check_loading.dart';
import '../widgets/time_check_error.dart';

/// Обертка для проверки времени перед показом основного экрана
class TimeCheckWrapper extends StatefulWidget {
  const TimeCheckWrapper({super.key});

  @override
  State<TimeCheckWrapper> createState() => _TimeCheckWrapperState();
}

class _TimeCheckWrapperState extends State<TimeCheckWrapper> {
  final _timeSecurityService = TimeSecurityService();
  bool _isChecking = true;
  TimeValidationResult? _validationResult;

  @override
  void initState() {
    super.initState();
    _checkTime();
  }

  Future<void> _checkTime() async {
    final result = await _timeSecurityService.validateTime();

    if (!mounted) return;

    setState(() {
      _validationResult = result;
      _isChecking = false;
    });

    // ИСПРАВЛЕНО: Навигация теперь выполняется в setState, не в build
    if (result.isValid && !result.isWarning) {
      _navigateToLockScreen();
    }
  }

  void _navigateToLockScreen() {
    // Планируем навигацию на следующий фрейм
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LockScreen(),
          ),
        );
      }
    });
  }

  Future<void> _continueAnyway() async {
    // Пользователь подтверждает, что хочет продолжить несмотря на предупреждение
    await _timeSecurityService.resetTamperFlag();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const LockScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const TimeCheckLoading();
    }

    // Если результат валидации положительный, показываем загрузку
    // (навигация происходит в initState/setState)
    if (_validationResult != null &&
        _validationResult!.isValid &&
        !_validationResult!.isWarning) {
      return const TimeCheckLoading();
    }

    // Показываем экран ошибки/предупреждения
    return TimeCheckError(
      validationResult: _validationResult!,
      onRetry: _checkTime,
      onContinue: _validationResult!.isWarning ? _continueAnyway : null,
    );
  }
}