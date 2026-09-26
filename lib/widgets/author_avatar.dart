import 'package:flutter/material.dart';
import '../services/api_constants.dart';
import '../theme/colors.dart';

/// Avatar de l'auteur : photo de profil si disponible, sinon initiale.
class AuthorAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double radius;

  const AuthorAvatar({
    super.key,
    required this.name,
    this.url,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = url != null && url!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      backgroundImage:
          hasPhoto ? NetworkImage(ApiConstants.formatMediaUrl(url)) : null,
      child:
          hasPhoto
              ? null
              : Text(
                name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'É',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: radius * 0.8,
                  color: AppColors.onPrimary,
                ),
              ),
    );
  }
}
