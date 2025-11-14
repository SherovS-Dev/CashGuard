import 'package:flutter/foundation.dart';
import 'package:screen_protector/screen_protector.dart';

class ScreenSecurityService {
  /// Включает защиту от скриншотов и записи экрана
  /// Работает на Android и iOS
  static Future<void> enableScreenSecurity() async {
    try {
      // Защита от скриншотов
      await ScreenProtector.protectDataLeakageOn();

      // Защита от записи экрана (работает на Android)
      if (defaultTargetPlatform == TargetPlatform.android) {
        await ScreenProtector.preventScreenshotOn();
      }

      debugPrint('Защита экрана включена: скриншоты и запись экрана заблокированы');
    } catch (e) {
      debugPrint('Ошибка при включении защиты экрана: $e');
    }
  }

  /// Отключает защиту от скриншотов (может потребоваться для отладки)
  static Future<void> disableScreenSecurity() async {
    try {
      await ScreenProtector.protectDataLeakageOff();

      if (defaultTargetPlatform == TargetPlatform.android) {
        await ScreenProtector.preventScreenshotOff();
      }

      debugPrint('Защита экрана отключена');
    } catch (e) {
      debugPrint('Ошибка при отключении защиты экрана: $e');
    }
  }
}
