import 'package:flutter/material.dart';
import 'screens/lock_screen.dart';
import 'services/time_security_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализируем сервис безопасности времени
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

    setState(() {
      _validationResult = result;
      _isChecking = false;
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
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.deepPurple.shade300,
                Colors.deepPurple.shade700,
                Colors.indigo.shade900,
              ],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 24),
                Text(
                  'Проверка безопасности...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Если время корректно - переходим к экрану блокировки
    if (_validationResult != null && _validationResult!.isValid && !_validationResult!.isWarning) {
      // Используем Future.microtask чтобы избежать вызова setState во время build
      Future.microtask(() {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const LockScreen(),
            ),
          );
        }
      });
      return const SizedBox.shrink();
    }

    // Показываем предупреждение или ошибку
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _validationResult!.isWarning
                ? [
              Colors.orange.shade300,
              Colors.orange.shade600,
              Colors.deepOrange.shade800,
            ]
                : [
              Colors.red.shade300,
              Colors.red.shade700,
              Colors.red.shade900,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Иконка предупреждения
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      _validationResult!.isWarning
                          ? Icons.warning_amber_rounded
                          : Icons.error_outline_rounded,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Заголовок
                  Text(
                    _validationResult!.isWarning
                        ? 'Предупреждение'
                        : 'Ошибка безопасности',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // Описание проблемы
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 48,
                          color: _validationResult!.isWarning
                              ? Colors.orange.shade700
                              : Colors.red.shade700,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _validationResult!.message,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade800,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        if (_validationResult!.lastKnownTime != null &&
                            _validationResult!.currentTime != null) ...[
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                          _TimeInfoRow(
                            label: 'Последнее время:',
                            time: _validationResult!.lastKnownTime!,
                          ),
                          const SizedBox(height: 12),
                          _TimeInfoRow(
                            label: 'Текущее время:',
                            time: _validationResult!.currentTime!,
                            isHighlight: true,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Инструкция
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Colors.white.withOpacity(0.9),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _validationResult!.isWarning
                                    ? 'Рекомендация'
                                    : 'Что делать?',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _validationResult!.isWarning
                              ? 'Проверьте правильность системного времени на вашем устройстве. Для корректной работы приложения рекомендуется использовать автоматическую настройку времени.'
                              : 'Пожалуйста, установите правильное системное время на вашем устройстве:\n\n'
                              '1. Откройте Настройки\n'
                              '2. Перейдите в Дата и время\n'
                              '3. Включите "Автоматическая дата и время"\n'
                              '4. Перезапустите приложение',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Кнопки действий
                  if (_validationResult!.isWarning)
                    Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _continueAnyway,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.orange.shade700,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Продолжить все равно',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _checkTime,
                          child: Text(
                            'Проверить снова',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _checkTime,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Проверить снова'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red.shade700,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
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

class _TimeInfoRow extends StatelessWidget {
  final String label;
  final DateTime time;
  final bool isHighlight;

  const _TimeInfoRow({
    required this.label,
    required this.time,
    this.isHighlight = false,
  });

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          _formatDateTime(time),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isHighlight ? Colors.red.shade700 : Colors.black87,
          ),
        ),
      ],
    );
  }
}