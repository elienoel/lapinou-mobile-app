import 'package:flutter/material.dart';
import '../models/cage.dart';
import '../services/api_constants.dart';
import '../theme/colors.dart';

/// Palette du modèle de cage (montants verts, grillage gris, plateaux marron).
class _CagePalette {
  static const Color post = Color(0xFF3E7F72);
  static const Color bar = Color(0xFF77BDB1);
  static const Color tray = Color(0xFF5B4B43);
  static const Color mesh = Color(0xFFA9A9A9);
  static const Color nestBox = Color(0xFF6B6B6B);
  static const Color foot = Color(0xFF7A7F94);
}

/// Représentation graphique d'une cage d'élevage : une colonne de loges
/// grillagées superposées (avec boîte à nid et loquet), posées sur des plateaux.
///
/// Le dessin s'adapte à la largeur disponible. En mode [compact] seules les
/// loges occupées sont signalées (aperçu pour les listes).
class CageDiagram extends StatelessWidget {
  final Cage cage;
  final bool compact;
  final int? highlightedCompartment;
  final ValueChanged<CageCompartment>? onCompartmentTap;

  const CageDiagram({
    super.key,
    required this.cage,
    this.compact = false,
    this.highlightedCompartment,
    this.onCompartmentTap,
  });

  // Proportions relevées sur le modèle (rapportées à la largeur intérieure).
  static const double _postRatio = 0.05;
  static const double _barRatio = 0.05;
  static const double _gridRatio = 0.60;
  static const double _gapRatio = 0.075;
  static const double _trayRatio = 0.08;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 220.0;
        final columns = cage.columnsCount;
        final rows = cage.rowsCount;
        // width = columns * innerW + (columns + 1) * postW, avec postW = ratio * innerW
        final innerW = width / (columns + (columns + 1) * _postRatio);
        final postW = innerW * _postRatio;
        final barH = innerW * _barRatio;
        final gridH = innerW * _gridRatio;
        final gapH = innerW * _gapRatio;
        final trayH = innerW * _trayRatio;
        final totalH = 2 * barH + rows * (gridH + gapH + trayH);

        return SizedBox(
          height: totalH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _post(postW),
              for (int c = 1; c <= columns; c++) ...[
                SizedBox(
                  width: innerW,
                  child: Column(
                    children: [
                      Container(height: barH, color: _CagePalette.bar),
                      for (int r = 1; r <= rows; r++)
                        _compartment(
                          cage.slotAt(r, c),
                          innerW: innerW,
                          gridH: gridH,
                          gapH: gapH,
                          trayH: trayH,
                        ),
                      Container(height: barH, color: _CagePalette.bar),
                    ],
                  ),
                ),
                _post(postW),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _post(double width) {
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Expanded(child: Container(color: _CagePalette.post)),
          Container(
            height: width * 0.35,
            margin: EdgeInsets.symmetric(horizontal: width * 0.15),
            decoration: BoxDecoration(
              color: _CagePalette.foot,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compartment(
    CageCompartment slot, {
    required double innerW,
    required double gridH,
    required double gapH,
    required double trayH,
  }) {
    final highlighted = highlightedCompartment == slot.number;
    return SizedBox(
      height: gridH + gapH + trayH,
      child: Column(
        children: [
          SizedBox(
            height: gridH,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _CompartmentPainter()),
                ),
                if (highlighted)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.goldAccent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: innerW * 0.025,
                  top: gridH * 0.05,
                  bottom: gridH * 0.05,
                  width: innerW * 0.47,
                  child: _occupantOverlay(slot, innerW),
                ),
                if (onCompartmentTap != null)
                  Positioned.fill(
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(onTap: () => onCompartmentTap!(slot)),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: gapH),
          Container(height: trayH, color: _CagePalette.tray),
        ],
      ),
    );
  }

  Widget _occupantOverlay(CageCompartment slot, double innerW) {
    final occupant = slot.occupant;
    final count = slot.occupants.length;
    final kits = slot.kitsCount;
    final numberBadge = Align(
      alignment: Alignment.topLeft,
      child: Container(
        width: (innerW * 0.06).clamp(12.0, 26.0),
        height: (innerW * 0.06).clamp(12.0, 26.0),
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: _CagePalette.post,
          shape: BoxShape.circle,
        ),
        child: Text(
          '${slot.number}',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: (innerW * 0.035).clamp(7.0, 14.0),
            height: 1,
          ),
        ),
      ),
    );

    if (compact) {
      return Stack(
        children: [
          if (occupant != null)
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '🐰',
                      style: TextStyle(
                        fontSize: (innerW * 0.16).clamp(10.0, 34.0),
                      ),
                    ),
                    // Plusieurs lapins dans la même loge : leur nombre
                    if (count > 1)
                      Text(
                        '×$count',
                        style: TextStyle(
                          fontSize: (innerW * 0.075).clamp(8.0, 16.0),
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    // Lapereaux non sevrés avec leur mère dans cette loge
                    if (kits > 0)
                      Text(
                        ' 🍼$kits',
                        style: TextStyle(
                          fontSize: (innerW * 0.075).clamp(8.0, 16.0),
                          fontWeight: FontWeight.w800,
                          color: AppColors.statusPregnantText,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          numberBadge,
        ],
      );
    }

    final nameSize = (innerW * 0.036).clamp(8.0, 16.0);
    final avatarSize = (innerW * 0.17).clamp(22.0, 64.0);
    final showDetails = innerW >= 150;

    Widget content;
    if (occupant == null) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.primaryLight,
              size: avatarSize * 0.6,
            ),
            if (showDetails) ...[
              const SizedBox(height: 2),
              Text(
                'Libre',
                style: TextStyle(
                  fontSize: nameSize,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      );
    } else if (count > 1) {
      // Plusieurs lapins : avatars côte à côte, noms, et nombre
      final shown = slot.occupants.take(3).toList();
      content = Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: innerW * 0.42),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final o in shown)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: _occupantAvatar(
                          o,
                          avatarSize * 0.72,
                          o.isMale ? AppColors.maleBlue : AppColors.femalePink,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  slot.occupants.map((o) => o.name).join(', '),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: nameSize,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (showDetails)
                  Text(
                    '$count lapins',
                    style: TextStyle(
                      fontSize: nameSize * 0.8,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                if (kits > 0) _kitsLabel(kits, nameSize),
              ],
            ),
          ),
        ),
      );
    } else {
      final accent =
          occupant.isMale ? AppColors.maleBlue : AppColors.femalePink;
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _occupantAvatar(occupant, avatarSize, accent),
            const SizedBox(height: 3),
            Text(
              occupant.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: nameSize,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            if (showDetails)
              Text(
                '${occupant.isMale ? '♂' : '♀'} ${occupant.tagNumber}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: nameSize * 0.8,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            if (kits > 0) _kitsLabel(kits, nameSize),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    occupant == null
                        ? AppColors.primarySoftBorder
                        : AppColors.cardBorder,
              ),
            ),
            child: content,
          ),
        ),
        numberBadge,
      ],
    );
  }

  /// « 🍼 7 lapereaux » : lapereaux non sevrés qui vivent avec la mère de cette loge.
  Widget _kitsLabel(int kits, double nameSize) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.statusPregnantBg,
        border: Border.all(color: AppColors.statusPregnantText),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '🍼 $kits lapereau${kits > 1 ? 'x' : ''}',
        maxLines: 1,
        style: TextStyle(
          fontSize: nameSize * 0.8,
          fontWeight: FontWeight.w700,
          color: AppColors.statusPregnantText,
        ),
      ),
    );
  }

  Widget _occupantAvatar(CageOccupant occupant, double size, Color accent) {
    final photo = occupant.photoUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primarySoft,
        border: Border.all(color: accent, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child:
          photo != null && photo.isNotEmpty
              ? Image.network(
                ApiConstants.formatMediaUrl(photo),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) =>
                        Text('🐰', style: TextStyle(fontSize: size * 0.5)),
              )
              : Text('🐰', style: TextStyle(fontSize: size * 0.5)),
    );
  }
}

/// Dessine le grillage d'une loge, sa boîte à nid, son loquet et ses charnières.
class _CompartmentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    // Grillage
    final mesh =
        Paint()
          ..color = _CagePalette.mesh
          ..strokeWidth = 1;
    final vStep = w * 0.032;
    for (double x = 0; x <= w; x += vStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), mesh);
    }
    final hStep = h * 0.108;
    for (double y = 0; y <= h; y += hStep) {
      canvas.drawLine(Offset(0, y), Offset(w, y), mesh);
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = _CagePalette.mesh
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Boîte à nid (cadre épais, grillage plus serré)
    final box = Rect.fromLTRB(w * 0.527, h * 0.09, w * 0.945, h * 0.80);
    canvas.drawRect(box, Paint()..color = Colors.white.withAlpha(150));
    final fine =
        Paint()
          ..color = _CagePalette.mesh
          ..strokeWidth = 1;
    for (double y = box.top; y <= box.bottom; y += h * 0.055) {
      canvas.drawLine(Offset(box.left, y), Offset(box.right, y), fine);
    }
    final side =
        Paint()
          ..color = _CagePalette.nestBox
          ..strokeWidth = w * 0.014;
    final topBottom =
        Paint()
          ..color = _CagePalette.nestBox
          ..strokeWidth = w * 0.009;
    canvas.drawLine(box.topLeft, box.bottomLeft, side);
    canvas.drawLine(box.topRight, box.bottomRight, side);
    canvas.drawLine(box.topLeft, box.topRight, topBottom);
    canvas.drawLine(box.bottomLeft, box.bottomRight, topBottom);

    // Loquet
    final latchY = h * 0.44;
    final latch =
        Paint()
          ..color = _CagePalette.nestBox
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = w * 0.008;
    final hookX = w * 0.965;
    canvas.drawLine(Offset(w * 0.72, latchY), Offset(hookX, latchY), latch);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(hookX, latchY - h * 0.02),
        width: w * 0.025,
        height: h * 0.04,
      ),
      -1.57,
      3.14,
      false,
      latch,
    );

    // Charnières sur les montants
    final hinge = Paint()..color = _CagePalette.mesh;
    for (final x in [0.0, w]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, h * 0.07),
          width: w * 0.02,
          height: h * 0.11,
        ),
        hinge,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CompartmentPainter oldDelegate) => false;
}
