import 'package:flutter/material.dart';

class AppColors {
  // ---- Couleur principale --------------------------------------------------
  // Pour changer la couleur de l'application, modifiez uniquement `primary`.
  // Règle de design : un fond est TOUJOURS soit `primary` (plein), soit blanc ;
  // jamais de fond teinté ou semi-transparent. La couleur s'exprime par les
  // fonds pleins, les bordures et les textes.
  static const Color primary = Color(0xFF000000);

  /// Texte et icônes posés sur un fond `primary`
  static const Color onPrimary = Colors.white;

  /// Exception à la règle ci-dessus, demandée pour les messages de l'utilisateur dans le fil :
  /// la couleur principale à très faible opacité (comme la bulle verte de WhatsApp).
  static final Color primaryTint = primary.withAlpha(9);

  /// Anciennes variantes de la couleur principale : identiques à `primary`
  static const Color primaryDark = primary;
  static const Color primaryLight = primary;

  /// Anciens fonds teintés : désormais blancs (voir la règle ci-dessus)
  static const Color primarySoft = Colors.white;

  /// Bordure fine des éléments (cards, pastilles, champs)
  static const Color primarySoftBorder = Color(0xFFE5E7EB);

  // Surface & Neutral tones : toutes les pages ont un fond blanc
  static const Color scaffoldBackground = Colors.white;
  static const Color backgroundGrey = Colors.white;
  static const Color cardSurface = Colors.white;
  static const Color cardBorder = Color(0xFFE5E7EB);

  // Typography
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Status badges
  static const Color statusActiveBg = Colors.white;
  static const Color statusActiveText = Color(0xFF1B5E20);

  static const Color statusPregnantBg = Colors.white;
  static const Color statusPregnantText = Color(0xFFE65100);

  static const Color statusRestingBg = Colors.white;
  static const Color statusRestingText = Color(0xFF5E35B1);

  static const Color statusAlertBg = Colors.white;
  static const Color statusAlertText = Color(0xFFC62828);

  // Accents
  static const Color maleBlue = Color(0xFF2563EB);
  static const Color femalePink = Color(0xFFDB2777);
  static const Color goldAccent = Color(0xFFF59E0B);
}
