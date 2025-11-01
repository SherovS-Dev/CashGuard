import 'package:flutter/material.dart';

class TimeInfoRow extends StatelessWidget {
  final String label;
  final DateTime time;
  final bool isHighlight;

  const TimeInfoRow({
    super.key,
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