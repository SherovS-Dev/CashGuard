import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

/// Сервис для защиты от манипуляций с системным временем
class TimeSecurityService {
  static final TimeSecurityService _instance = TimeSecurityService._internal();
  factory TimeSecurityService() => _instance;
  TimeSecurityService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const String _lastKnownTimeKey = 'last_known_time';
  static const String _timeTamperDetectedKey = 'time_tamper_detected';
  static const String _appInstallTimeKey = 'app_install_time';

  /// Инициализация при первом запуске
  Future<void> initialize() async {
    final installTime = await _secureStorage.read(key: _appInstallTimeKey);
    if (installTime == null) {
      // Первый запуск - сохраняем время установки
      await _secureStorage.write(
        key: _appInstallTimeKey,
        value: DateTime.now().millisecondsSinceEpoch.toString(),
      );
    }

    // Сохраняем текущее время
    await _updateLastKnownTime();
  }

  /// Обновление последнего известного времени
  Future<void> _updateLastKnownTime() async {
    final now = DateTime.now();
    final timeData = {
      'timestamp': now.millisecondsSinceEpoch,
      'date': now.toIso8601String(),
    };
    await _secureStorage.write(
      key: _lastKnownTimeKey,
      value: jsonEncode(timeData),
    );
  }

  /// Проверка на манипуляции с временем
  Future<TimeValidationResult> validateTime() async {
    try {
      final lastTimeStr = await _secureStorage.read(key: _lastKnownTimeKey);

      if (lastTimeStr == null) {
        // Первый запуск или данные отсутствуют
        await _updateLastKnownTime();
        return TimeValidationResult(
          isValid: true,
          message: 'Время инициализировано',
        );
      }

      final lastTimeData = jsonDecode(lastTimeStr) as Map<String, dynamic>;
      final lastTimestamp = lastTimeData['timestamp'] as int;
      final lastDateTime = DateTime.fromMillisecondsSinceEpoch(lastTimestamp);
      final now = DateTime.now();

      // Проверка 1: Время не должно идти назад
      if (now.isBefore(lastDateTime)) {
        final difference = lastDateTime.difference(now);
        await _markTimeTamper(true);

        return TimeValidationResult(
          isValid: false,
          message: 'Обнаружена попытка отмотать время назад на ${_formatDuration(difference)}',
          tamperedBy: difference,
          lastKnownTime: lastDateTime,
          currentTime: now,
        );
      }

      // Проверка 2: Проверка на подозрительные скачки времени вперед
      final timeDifference = now.difference(lastDateTime);

      // Если прошло более 7 дней с момента последнего запуска - это подозрительно
      // (обычно пользователи открывают приложение чаще)
      if (timeDifference.inDays > 7) {
        // Это предупреждение, но не блокировка
        await _updateLastKnownTime();
        return TimeValidationResult(
          isValid: true,
          isWarning: true,
          message: 'Прошло ${timeDifference.inDays} дней с момента последнего использования',
          tamperedBy: timeDifference,
          lastKnownTime: lastDateTime,
          currentTime: now,
        );
      }

      // Проверка 3: Проверка времени установки приложения
      final installTimeStr = await _secureStorage.read(key: _appInstallTimeKey);
      if (installTimeStr != null) {
        final installTimestamp = int.parse(installTimeStr);
        final installDateTime = DateTime.fromMillisecondsSinceEpoch(installTimestamp);

        if (now.isBefore(installDateTime)) {
          await _markTimeTamper(true);
          return TimeValidationResult(
            isValid: false,
            message: 'Текущее время раньше времени установки приложения',
            lastKnownTime: installDateTime,
            currentTime: now,
          );
        }
      }

      // Все проверки пройдены
      await _updateLastKnownTime();
      await _markTimeTamper(false);

      return TimeValidationResult(
        isValid: true,
        message: 'Время корректно',
      );
    } catch (e) {
      // В случае ошибки не блокируем приложение
      return TimeValidationResult(
        isValid: true,
        message: 'Ошибка проверки времени: $e',
      );
    }
  }

  /// Отметить обнаружение манипуляции с временем
  Future<void> _markTimeTamper(bool detected) async {
    await _secureStorage.write(
      key: _timeTamperDetectedKey,
      value: detected.toString(),
    );
  }

  /// Проверить, была ли обнаружена манипуляция с временем
  Future<bool> wasTimeTamperDetected() async {
    final detected = await _secureStorage.read(key: _timeTamperDetectedKey);
    return detected == 'true';
  }

  /// Сброс флага манипуляции (для использования администратором)
  Future<void> resetTamperFlag() async {
    await _markTimeTamper(false);
  }

  /// Форматирование длительности
  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} дн.';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} ч.';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} мин.';
    } else {
      return '${duration.inSeconds} сек.';
    }
  }

  /// Получить информацию о времени для отладки
  Future<Map<String, dynamic>> getTimeInfo() async {
    final lastTimeStr = await _secureStorage.read(key: _lastKnownTimeKey);
    final installTimeStr = await _secureStorage.read(key: _appInstallTimeKey);
    final tamperDetected = await wasTimeTamperDetected();

    DateTime? lastTime;
    DateTime? installTime;

    if (lastTimeStr != null) {
      final data = jsonDecode(lastTimeStr) as Map<String, dynamic>;
      lastTime = DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int);
    }

    if (installTimeStr != null) {
      installTime = DateTime.fromMillisecondsSinceEpoch(int.parse(installTimeStr));
    }

    return {
      'currentTime': DateTime.now(),
      'lastKnownTime': lastTime,
      'installTime': installTime,
      'tamperDetected': tamperDetected,
    };
  }

  /// Очистка всех данных о времени (только для тестирования)
  Future<void> clearTimeData() async {
    await _secureStorage.delete(key: _lastKnownTimeKey);
    await _secureStorage.delete(key: _timeTamperDetectedKey);
    // Не удаляем время установки - это константа
  }
}

/// Результат валидации времени
class TimeValidationResult {
  final bool isValid;
  final bool isWarning;
  final String message;
  final Duration? tamperedBy;
  final DateTime? lastKnownTime;
  final DateTime? currentTime;

  TimeValidationResult({
    required this.isValid,
    this.isWarning = false,
    required this.message,
    this.tamperedBy,
    this.lastKnownTime,
    this.currentTime,
  });

  @override
  String toString() {
    return 'TimeValidationResult(isValid: $isValid, isWarning: $isWarning, message: $message)';
  }
}