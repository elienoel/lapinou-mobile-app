import 'package:flutter/material.dart';

class AppColors {
  // ---- Identité Clap'in : noir (logo) + violet ---------------------------------
  // `primary` (noir) porte l'identité du logo : textes forts, contours, fonds pleins.
  // `secondary` (violet) apporte la couleur : boutons, navigation, accents,
  // dégradés et pastilles teintées.
  static const Color primary = Color(0xFF000000);

  /// Texte et icônes posés sur un fond `primary`
  static const Color onPrimary = Colors.white;

  /// Exception à la règle ci-dessus, demandée pour les messages de l'utilisateur dans le fil :
  /// la couleur principale à très faible opacité (comme la bulle verte de WhatsApp).
  static final Color primaryTint = primary.withAlpha(9);

  // ---- Couleur secondaire : violet -------------------------------------------
  static const Color secondary = Color(0xFF6A5F8C);
  static const Color secondaryDark = Color(0xFF453D5E);
  static const Color secondaryLight = Color(0xFFA49CC0);

  /// Fond violet très clair (pastilles d'icônes, badges, cartes de race)
  static const Color secondarySoft = Color(0xFFEFEDF4);
  static final Color secondaryTint = secondary.withAlpha(22);

  /// Fond de toutes les pages : `secondary` à ~9 % d'opacité, déjà mélangé
  /// au blanc (couleur opaque, rien ne transparaît des écrans dessous).
  static const Color pageBackground = Color(0xFFF0EFF4);

  /// Dégradé de marque : du noir du logo vers le violet
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A0A0F), Color(0xFF453D5E), secondary],
    stops: [0.0, 0.55, 1.0],
  );

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
