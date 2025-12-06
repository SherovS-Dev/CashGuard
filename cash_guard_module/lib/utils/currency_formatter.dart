import 'package:flutter/material.dart';

/// Утилита для форматирования валюты (сомони - TJS)
class CurrencyFormatter {
  /// Символ валюты сомони
  static const String currencySymbol = 'ЅМ';

  /// Код валюты
  static const String currencyCode = 'TJS';

  /// Форматирует сумму в строку с символом валюты
  static String format(double amount) {
    return '${amount.toStringAsFixed(2)} $currencySymbol';
  }
}

/// Виджет для красивого отображения валюты с эффектом
class CurrencyText extends StatefulWidget {
  final double amount;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final bool showEffect;
  final bool animate;

  const CurrencyText({
    super.key,
    required this.amount,
    this.fontSize = 16,
    this.fontWeight = FontWeight.normal,
    this.color,
    this.showEffect = true,
    this.animate = false,
  });

  @override
  State<CurrencyText> createState() => _CurrencyTextState();
}

class _CurrencyTextState extends State<CurrencyText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller = AnimationController(
        duration: const Duration(milliseconds: 2000),
        vsync: this,
      )..repeat();

      _shimmerAnimation = Tween<double>(begin: -2, end: 2).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void dispose() {
    if (widget.animate) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.color ?? Colors.black87;

    if (!widget.showEffect) {
      return Text(
        CurrencyFormatter.format(widget.amount),
        style: TextStyle(
          fontSize: widget.fontSize,
          fontWeight: widget.fontWeight,
          color: textColor,
        ),
      );
    }

    final textWidget = Text(
      CurrencyFormatter.format(widget.amount),
      style: TextStyle(
        fontSize: widget.fontSize,
        fontWeight: widget.fontWeight,
        foreground: Paint()
          ..shader = LinearGradient(
            colors: [
              textColor,
              textColor.withValues(alpha: 0.7),
              textColor,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
        shadows: [
          Shadow(
            color: textColor.withValues(alpha: 0.4),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
          Shadow(
            color: textColor.withValues(alpha: 0.2),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
    );

    if (!widget.animate) {
      return textWidget;
    }

    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                textColor.withValues(alpha: 0.7),
                textColor,
                Colors.white.withValues(alpha: 0.8),
                textColor,
                textColor.withValues(alpha: 0.7),
              ],
              stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
              transform: GradientRotation(_shimmerAnimation.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: textWidget,
    );
  }
}

/// Расширение для удобного использования
extension DoubleExtension on double {
  /// Форматирует число в валюту
  String toCurrency() {
    return CurrencyFormatter.format(this);
  }
}
