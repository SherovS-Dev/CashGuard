import 'package:flutter/material.dart';
import '../constants/color_palettes.dart';

/// Виджет для выбора цвета из палитры
class ColorPickerWidget extends StatelessWidget {
  final int selectedColorIndex;
  final ValueChanged<int> onColorSelected;

  const ColorPickerWidget({
    super.key,
    required this.selectedColorIndex,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Выберите цвет',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(ColorPalettes.count, (index) {
                final gradient = ColorPalettes.getGradient(index);
                final isSelected = index == selectedColorIndex;

                return Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 0 : 8,
                    right: index == ColorPalettes.count - 1 ? 0 : 8,
                  ),
                  child: GestureDetector(
                    onTap: () => onColorSelected(index),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradient,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected
                            ? Border.all(
                                color: Colors.deepPurple.shade700,
                                width: 3,
                              )
                            : Border.all(
                                color: Colors.grey.shade300,
                                width: 2,
                              ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: gradient[0].withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Center(
                              child: Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 32,
                                shadows: [
                                  Shadow(
                                    color: Colors.black45,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            )
                          : null,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}
