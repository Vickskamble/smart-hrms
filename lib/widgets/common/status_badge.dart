import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case 'Approved':
        bgColor = AppColors.green.withValues(alpha: 0.15);
        textColor = AppColors.green;
        break;
      case 'Rejected':
        bgColor = AppColors.red.withValues(alpha: 0.15);
        textColor = AppColors.red;
        break;
      default:
        bgColor = AppColors.amber.withValues(alpha: 0.15);
        textColor = AppColors.amber;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}