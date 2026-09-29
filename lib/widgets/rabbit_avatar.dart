import 'package:flutter/material.dart';
import '../models/rabbit.dart';
import '../services/api_constants.dart';
import '../theme/colors.dart';
import 'app_icon.dart';

class RabbitAvatar extends StatelessWidget {
  final Rabbit rabbit;
  final double size;
  final bool showGenderBadge;

  const RabbitAvatar({
    super.key,
    required this.rabbit,
    this.size = 50,
    this.showGenderBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    // Fond blanc uni : la couleur n'apparaît que par la bordure et le contenu
    const bgColor = AppColors.primarySoft;
    final photoUrl = rabbit.primaryPhotoUrl;

    Widget content;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      final formattedUrl = ApiConstants.formatMediaUrl(photoUrl);
      content = ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.32),
        child: Image.network(
          formattedUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder:
              (context, error, stackTrace) => _buildEmojiFallback(size),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: bgColor,
              child: Center(
                child: SizedBox(
                  width: size * 0.35,
                  height: size * 0.35,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
        ),
      );
    } else {
      content = _buildEmojiFallback(size);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(size * 0.32),
            border: Border.all(color: AppColors.cardBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: content,
        ),
        if (showGenderBadge)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                rabbit.isMale ? '♂' : '♀',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmojiFallback(double size) {
    return AppIcon(AppIcons.rabbit, size: size * 0.56, color: AppColors.primary);
  }
}
