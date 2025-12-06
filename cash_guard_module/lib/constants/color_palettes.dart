import 'package:flutter/material.dart';

/// Палитра цветовых градиентов для средств
class ColorPalettes {
  /// Список всех доступных градиентов
  static final List<List<Color>> gradients = [
    // 0 - Зеленый (деньги, природа)
    [const Color(0xFF11998e), const Color(0xFF38ef7d)],

    // 1 - Фиолетовый (элегантный)
    [const Color(0xFF667eea), const Color(0xFF764ba2)],

    // 2 - Голубой (спокойный)
    [const Color(0xFF2193b0), const Color(0xFF6dd5ed)],

    // 3 - Розовый (мягкий)
    [const Color(0xFFee9ca7), const Color(0xFFffdde1)],

    // 4 - Оранжевый (энергичный)
    [const Color(0xFFf46b45), const Color(0xFFeea849)],

    // 5 - Красный (страстный)
    [const Color(0xFFEB3349), const Color(0xFFF45C43)],

    // 6 - Темный фиолетовый (премиальный)
    [const Color(0xFF6a3093), const Color(0xFFa044ff)],

    // 7 - Темный синий (профессиональный)
    [const Color(0xFF141E30), const Color(0xFF243B55)],

    // 8 - Темно-зеленый (деловой)
    [const Color(0xFF134E5E), const Color(0xFF71B280)],

    // 9 - Лавандовый (нежный)
    [const Color(0xFFc471f5), const Color(0xFFfa71cd)],

    // 10 - Морской (освежающий)
    [const Color(0xFF00d2ff), const Color(0xFF3a7bd5)],

    // 11 - Золотой (роскошный)
    [const Color(0xFFf7971e), const Color(0xFFffd200)],

    // 12 - Персиковый (теплый)
    [const Color(0xFFf093fb), const Color(0xFFf5576c)],

    // 13 - Мятный (свежий)
    [const Color(0xFF4facfe), const Color(0xFF00f2fe)],

    // 14 - Сиреневый (романтичный)
    [const Color(0xFFa8edea), const Color(0xFFfed6e3)],

    // 15 - Черничный (глубокий)
    [const Color(0xFF360033), const Color(0xFF0b8793)],
  ];

  /// Получить градиент по индексу
  static List<Color> getGradient(int index) {
    if (index < 0 || index >= gradients.length) {
      return gradients[0]; // Возвращаем первый градиент по умолчанию
    }
    return gradients[index];
  }

  /// Количество доступных градиентов
  static int get count => gradients.length;
}
