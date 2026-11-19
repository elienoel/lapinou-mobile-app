import 'package:flutter/material.dart';
import '../models/rabbit.dart';
import '../services/api_constants.dart';
import '../theme/colors.dart';
import 'app_icon.dart';

/// Photos de la femelle et du mâle d'un accouplement, superposées :
/// la femelle devant, le mâle légèrement décalé derrière.
class PairAvatars extends StatelessWidget {
  const PairAvatars({
    super.key,
    required this.female,
    required this.male,
    this.size = 46,
  });

  final Rabbit? female;
  final Rabbit? male;
  final double size;

  @override
  Widget build(BuildContext context) {
    final overlap = size * 0.58;
    return SizedBox(
      width: size + overlap,
      height: size,
      child: Stack(
        children: [
          Positioned(
            left: overlap,
            child: _CircleAvatar(
              rabbit: male,
              size: size,
              accent: AppColors.maleBlue,
            ),
          ),
          _CircleAvatar(
            rabbit: female,
            size: size,
            accent: AppColors.femalePink,
          ),
        ],
      ),
    );
  }
}

class _CircleAvatar extends StatelessWidget {
  const _CircleAvatar({
    required this.rabbit,
    required this.size,
    required this.accent,
  });

  final Rabbit? rabbit;
  final double size;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final photo = rabbit?.primaryPhotoUrl;
    final fallback = Center(
      child: AppIcon(AppIcons.rabbit, size: size * 0.5, color: accent),
    );
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: ColoredBox(
          color: accent.withAlpha(22),
          child:
              photo != null && photo.isNotEmpty
                  ? Image.network(
                    ApiConstants.formatMediaUrl(photo),
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    errorBuilder: (_, __, ___) => fallback,
                  )
                  : fallback,
        ),
      ),
    );
  }
}
