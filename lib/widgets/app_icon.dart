import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/care.dart';
import '../theme/colors.dart';

/// Icônes vectorielles de l'application (dessins au trait, fichiers SVG dans `assets/icons/`).
enum AppIcons {
  /// Lapin : cheptel, fiches lapins
  rabbit('assets/icons/rabbit.svg'),

  /// Deux lapins et un cœur : accouplements
  mating('assets/icons/mating.svg'),

  /// Portée de lapereaux au nid : mises bas
  nest('assets/icons/nest.svg'),

  /// Seringue : soins, vaccins
  syringe('assets/icons/syringe.svg');

  final String asset;
  const AppIcons(this.asset);
}

/// Affiche une icône de [AppIcons] à la taille [size] et dans la couleur [color].
///
/// Le dessin est monochrome : sa couleur est appliquée à l'affichage, on peut donc l'adapter
/// au fond (noir sur blanc, blanc sur noir, couleur de statut…). Sans [color], elle suit
/// le thème d'icônes courant ([IconTheme]), comme une icône Material.
class AppIcon extends StatelessWidget {
  final AppIcons icon;
  final double size;
  final Color? color;
  final String? semanticLabel;

  const AppIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? IconTheme.of(context).color ?? AppColors.primary;
    return SvgPicture.asset(
      icon.asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticsLabel: semanticLabel,
      // Le SVG est noir : `srcIn` le teinte de la couleur demandée en gardant sa forme
      colorFilter: ColorFilter.mode(resolved, BlendMode.srcIn),
    );
  }
}

/// Pictogramme d'une famille de soins : la seringue pour les vaccins, une icône Material sinon.
class CareCategoryIcon extends StatelessWidget {
  final CareCategory category;
  final double size;
  final Color? color;

  const CareCategoryIcon(
    this.category, {
    super.key,
    this.size = 24,
    this.color,
  });

  static IconData _materialIcon(CareCategory c) => switch (c) {
    CareCategory.vitamin => Icons.eco_outlined,
    CareCategory.deworming => Icons.bug_report_outlined,
    CareCategory.antiparasitic => Icons.pest_control_outlined,
    CareCategory.coccidiosis => Icons.science_outlined,
    CareCategory.antibiotic => Icons.medication_outlined,
    _ => Icons.medical_services_outlined,
  };

  @override
  Widget build(BuildContext context) {
    if (category == CareCategory.vaccine) {
      return AppIcon(AppIcons.syringe, size: size, color: color);
    }
    return Icon(_materialIcon(category), size: size, color: color);
  }
}
