import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// Bord inférieur en légère vague d'une zone colorée (au-dessus), pour passer
/// en douceur au fond de la page (en dessous).
///
/// Reprend le tracé SVG fourni (viewBox 1440×320) : seule la bande où se
/// trouve la vague (y de 190 à 246) est dessinée, à l'échelle de la largeur.
/// Sous la vague, trois lames de la même couleur, de plus en plus
/// transparentes, font un dégradé. La 1re est 3 fois plus large que la 2e,
/// la 2e 2 fois plus large que la 3e.
class WaveEdge extends StatelessWidget {
  const WaveEdge({super.key, required this.color, this.firstBlade});

  final Color color;

  /// Largeur (px) de la 1re lame, la plus proche de la vague pleine ; les
  /// deux autres en découlent. Par défaut, proportionnelle à la largeur.
  final double? firstBlade;

  /// Largeur (px) des trois lames, de la plus proche à la plus éloignée.
  static List<double> bladeWidths(double first) => [
    first,
    first / 3,
    first / 6,
  ];

  /// Hauteur (px) de la vague seule, pour une largeur donnée.
  static double waveHeight(double width) =>
      _WavePainter.bandHeight * width / _WavePainter.viewWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final blades = bladeWidths(
          firstBlade ?? 64 * width / _WavePainter.viewWidth,
        );
        return SizedBox(
          width: width,
          height: waveHeight(width) + blades.reduce((a, b) => a + b),
          child: CustomPaint(painter: _WavePainter(color, blades)),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.color, this.blades);

  final Color color;

  /// Largeur des lames, de la plus proche de la vague à la plus éloignée.
  final List<double> blades;

  static const double viewWidth = 1440;
  static const double bandTop = 190;
  static const double bandHeight = 56;

  /// Opacité des lames, de la plus proche de la vague à la plus éloignée.
  static const List<int> bladeAlphas = [120, 75, 35];

  Path _wave(double s, double dy) {
    Offset p(double x, double y) => Offset(x * s, (y - bandTop) * s + dy);

    // M0,224 L120,229.3 C240,235 480,245 720,240
    // C960,235 1200,213 1320,202.7 L1440,192 L1440,0 L0,0 Z
    final a = p(0, 224), b = p(120, 229.3);
    final c1 = p(240, 235), c2 = p(480, 245), c3 = p(720, 240);
    final d1 = p(960, 235), d2 = p(1200, 213), d3 = p(1320, 202.7);
    final e = p(1440, 192);
    return Path()
      ..moveTo(0, 0)
      ..lineTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, c3.dx, c3.dy)
      ..cubicTo(d1.dx, d1.dy, d2.dx, d2.dy, d3.dx, d3.dy)
      ..lineTo(e.dx, e.dy)
      ..lineTo(viewWidth * s, 0)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / viewWidth;
    // Bord bas de chaque lame : cumul des largeurs. La plus éloignée est
    // dessinée en premier, les plus proches par-dessus.
    final offsets = <double>[];
    var total = 0.0;
    for (final w in blades) {
      offsets.add(total += w);
    }
    for (var i = blades.length - 1; i >= 0; i--) {
      canvas.drawPath(
        _wave(s, offsets[i]),
        Paint()..color = color.withAlpha(bladeAlphas[i]),
      );
    }
    canvas.drawPath(_wave(s, 0), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.color != color || !listEquals(old.blades, blades);
}
