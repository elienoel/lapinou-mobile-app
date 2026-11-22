import '../config/features.dart';

/// Annonce (image 16:9) d'un carrousel de la page d'accueil, gérée dans
/// l'admin Django (`promotions`). Un appui ouvre un écran de l'app, un site
/// web, ou rien.
class PromoSlide {
  final int id;
  final String imageUrl;
  final String title;

  /// `none`, `internal` ou `external`
  final String linkType;

  /// Écran ouvert quand [linkType] vaut `internal` (ex. `pharmacy`).
  final String? targetScreen;

  /// Site ouvert quand [linkType] vaut `external`.
  final String? externalUrl;

  const PromoSlide({
    required this.id,
    required this.imageUrl,
    this.title = '',
    this.linkType = 'none',
    this.targetScreen,
    this.externalUrl,
  });

  /// Faux pour une annonce qui mène vers un module masqué dans cette version.
  bool get isAvailable {
    if (linkType != 'internal') return true;
    return switch (targetScreen) {
      'pharmacy' => Features.pharmacy,
      'marketplace' => Features.marketplace,
      _ => true,
    };
  }

  factory PromoSlide.fromJson(Map<String, dynamic> json) {
    String? nonEmpty(dynamic v) =>
        v is String && v.trim().isNotEmpty ? v.trim() : null;
    return PromoSlide(
      id: json['id'] as int,
      imageUrl: json['image'] as String? ?? '',
      title: json['title'] as String? ?? '',
      linkType: json['link_type'] as String? ?? 'none',
      targetScreen: nonEmpty(json['target_screen']),
      externalUrl: nonEmpty(json['external_url']),
    );
  }
}

/// Carrousel d'annonces : les carrousels et leurs images arrivent déjà
/// filtrés (actifs) et triés par le serveur.
class PromoCarousel {
  final int id;
  final String name;
  final List<PromoSlide> slides;

  const PromoCarousel({
    required this.id,
    required this.name,
    required this.slides,
  });

  factory PromoCarousel.fromJson(Map<String, dynamic> json) => PromoCarousel(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    slides: [
      for (final s in (json['slides'] as List? ?? const []))
        PromoSlide.fromJson(Map<String, dynamic>.from(s as Map)),
    ].where((s) => s.imageUrl.isNotEmpty && s.isAvailable).toList(),
  );
}
