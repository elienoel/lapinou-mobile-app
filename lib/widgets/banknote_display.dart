import 'package:flutter/material.dart';

/// Billets disponibles dans les assets de l'application (francs CFA BCEAO).
enum CfaBanknote {
  f10000(10000, 'assets/money/10000f.jpeg', '10 000 F'),
  f5000(5000, 'assets/money/5000f.jpeg', '5 000 F'),
  f2000(2000, 'assets/money/2000f.jpeg', '2 000 F'),
  f1000(1000, 'assets/money/1000f.jpeg', '1 000 F'),
  f500(500, 'assets/money/500f.jpeg', '500 F');

  final int value;
  final String assetPath;
  final String label;

  const CfaBanknote(this.value, this.assetPath, this.label);
}

/// Décompose un montant en billets CFA selon les règles demandées :
/// - Si le montant dépasse 50 000 : représenté par 1 billet de 10 000.
/// - Si montant <= 0 : liste vide.
/// - Sinon : décomposition gloutonne avec 10 000, 5 000, 2 000, 1 000, 500
///   (ex: 15 000 -> [10000, 5000], 40 000 -> 4x 10000,
///   12 000 -> [10000, 2000], 17 500 -> [10000, 5000, 2000, 500]).
List<CfaBanknote> breakdownCfaAmount(double rawAmount) {
  if (rawAmount <= 0) return const [];
  final amount = rawAmount.round();
  if (amount > 50000) {
    return const [CfaBanknote.f10000];
  }

  final result = <CfaBanknote>[];
  var remaining = amount;

  const denominations = [
    CfaBanknote.f10000,
    CfaBanknote.f5000,
    CfaBanknote.f2000,
    CfaBanknote.f1000,
    CfaBanknote.f500,
  ];

  for (final note in denominations) {
    while (remaining >= note.value) {
      result.add(note);
      remaining -= note.value;
    }
  }

  // Si après décomposition il reste une fraction >= 250 (ex: 750 restait 250 après 500),
  // on arrondit au plus proche 500 pour une illustration fidèle
  if (remaining >= 250) {
    result.add(CfaBanknote.f500);
  }

  return result;
}

/// Widget d'un billet individuel avec bordures arrondies et ombre réaliste.
/// Peut être orienté verticalement (debout, format portrait) ou horizontalement.
class BanknoteItem extends StatelessWidget {
  final CfaBanknote banknote;
  final double width;
  final double height;
  final double borderRadius;
  final double rotation;
  final bool isVertical;

  const BanknoteItem({
    super.key,
    required this.banknote,
    this.width = 44,
    this.height = 68,
    this.borderRadius = 4,
    this.rotation = 0.0,
    this.isVertical = true,
  });

  @override
  Widget build(BuildContext context) {
    // Si isVertical est vrai, le billet est affiché en mode portrait (debout).
    // On pivote l'image horizontale de 90° dans le conteneur vertical.
    Widget content = isVertical
        ? SizedBox(
            width: width,
            height: height,
            child: Center(
              child: RotatedBox(
                quarterTurns: 3, // Tourne de 90° pour afficher le billet debout
                child: SizedBox(
                  width: height,
                  height: width,
                  child: Image.asset(
                    banknote.assetPath,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        banknote.label,
                        style: TextStyle(
                          fontSize: width * 0.28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        : SizedBox(
            width: width,
            height: height,
            child: Image.asset(
              banknote.assetPath,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  banknote.label,
                  style: TextStyle(
                    fontSize: height * 0.28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          );

    Widget card = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(1, 2),
          ),
        ],
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      ),
    );

    if (rotation != 0.0) {
      card = Transform.rotate(
        angle: rotation,
        child: card,
      );
    }

    return card;
  }
}

/// Pile superposée de billets (utilisée dans la card de transaction).
/// Présente les billets verticalement avec une largeur fixe dédiée pour la card.
class BanknoteStackIcon extends StatelessWidget {
  final double amount;
  final bool isIncome;
  final double fixedSlotWidth;
  final double noteWidth;
  final double noteHeight;
  final double borderWidth;
  final Color borderColor;

  const BanknoteStackIcon({
    super.key,
    required this.amount,
    required this.isIncome,
    this.fixedSlotWidth = 62.0,
    this.noteWidth = 32.0,
    this.noteHeight = 48.0,
    this.borderWidth = 3.5,
    this.borderColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final notes = breakdownCfaAmount(amount);

    if (notes.isEmpty) {
      return SizedBox(
        width: fixedSlotWidth,
        child: Center(
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
                  isIncome ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isIncome ? Icons.add_circle_outline : Icons.remove_circle_outline,
              color:
                  isIncome ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
              size: 20,
            ),
          ),
        ),
      );
    }

    final totalNotes = notes.length;
    // Calcule le pas de décalage pour tenir dans fixedSlotWidth
    final double maxOffset = totalNotes > 1
        ? (fixedSlotWidth - noteWidth) / (totalNotes - 1)
        : 0.0;
    // On borne le décalage pour garder une superposition élégante
    final double step = maxOffset > 8.0 ? 8.0 : maxOffset;
    final double usedWidth = noteWidth + (totalNotes - 1) * step;
    final double startLeft = (fixedSlotWidth - usedWidth) / 2.0;

    // Définition des décalages relatifs (x, y) et rotations de chaque billet
    final offsets = <Offset>[];
    final rotations = <double>[];
    for (var i = 0; i < totalNotes; i++) {
      final x = startLeft + (i * step);
      final y = (i % 2 == 1) ? 2.0 : 0.0;
      final rot = i == 0 ? 0.0 : ((i % 2 == 1 ? 0.04 : -0.04) * (i > 2 ? 0.5 : 1.0));
      offsets.add(Offset(x, y));
      rotations.add(rot);
    }

    Widget buildBanknoteGroup({bool isBorderSilhouette = false}) {
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          for (var i = 0; i < totalNotes; i++)
            Positioned(
              left: offsets[i].dx,
              top: offsets[i].dy,
              child: isBorderSilhouette
                  ? Transform.rotate(
                      angle: rotations[i],
                      child: Container(
                        width: noteWidth,
                        height: noteHeight,
                        decoration: BoxDecoration(
                          color: borderColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    )
                  : BanknoteItem(
                      banknote: notes[i],
                      width: noteWidth,
                      height: noteHeight,
                      isVertical: true,
                      borderRadius: 4,
                      rotation: rotations[i],
                    ),
            ),
        ],
      );
    }

    // Si borderWidth > 0, on génère une silhouette blanche continue tout autour
    // du groupe superposé en échantillonnant les angles avec un petit rayon.
    // Cela crée un bord extérieur blanc uniforme qui épouse exactement le contour
    // global du bloc de billets sans tracer de bordure sur les billets individuels.
    if (borderWidth > 0) {
      final r = borderWidth;
      // 8 directions cardinales + intercardinales pour un contour propre et régulier
      final d = r * 0.7071;
      final borderOffsets = [
        Offset(-r, 0),
        Offset(r, 0),
        Offset(0, -r),
        Offset(0, r),
        Offset(-d, -d),
        Offset(d, -d),
        Offset(-d, d),
        Offset(d, d),
      ];

      return SizedBox(
        width: fixedSlotWidth,
        height: noteHeight + 4,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerLeft,
          children: [
            // Couche contour blanc extérieur
            for (final bo in borderOffsets)
              Transform.translate(
                offset: bo,
                child: buildBanknoteGroup(isBorderSilhouette: true),
              ),
            // Billets intérieurs intacts
            buildBanknoteGroup(isBorderSilhouette: false),
          ],
        ),
      );
    }

    return SizedBox(
      width: fixedSlotWidth,
      height: noteHeight + 4,
      child: buildBanknoteGroup(isBorderSilhouette: false),
    );
  }
}

/// Grande illustration chorégraphiée des billets au-dessus du champ montant.
/// Présentée verticalement (debout) avec superposition et scroll horizontal si besoin.
class BanknoteAmountIllustration extends StatelessWidget {
  final double amount;
  final bool isIncome;

  const BanknoteAmountIllustration({
    super.key,
    required this.amount,
    required this.isIncome,
  });

  @override
  Widget build(BuildContext context) {
    final notes = breakdownCfaAmount(amount);

    if (notes.isEmpty) {
      return Container(
        height: 94,
        alignment: Alignment.center,
        child: Text(
          'Entrez un montant pour voir l\'illustration en billets',
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Colors.grey.shade400,
          ),
        ),
      );
    }

    // Billets en grand format vertical (debout)
    const noteW = 56.0;
    const noteH = 90.0;
    const overlap = 22.0;

    final contentWidth = noteW + (notes.length - 1) * overlap;

    return Container(
      height: noteH + 14,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: SizedBox(
          width: contentWidth < 80 ? 80 : contentWidth,
          height: noteH + 10,
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < notes.length; i++)
                Positioned(
                  left: i * overlap,
                  top: 4 + (i % 2 == 1 ? 2 : -2),
                  child: BanknoteItem(
                    banknote: notes[i],
                    width: noteW,
                    height: noteH,
                    isVertical: true,
                    borderRadius: 5,
                    rotation: (i % 2 == 1 ? 0.04 : -0.03) * (i > 3 ? 0.5 : 1.0),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
