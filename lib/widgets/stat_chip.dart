import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';

class StatChip extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final bool isHighlighted;
  final VoidCallback? onTap;

  const StatChip({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.isHighlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isHighlighted ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: isHighlighted ? AppColors.primary : AppColors.cardBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isHighlighted ? 15 : 6),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isHighlighted ? Colors.white : AppColors.textPrimary,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color:
                    isHighlighted
                        ? Colors.white.withAlpha(220)
                        : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
