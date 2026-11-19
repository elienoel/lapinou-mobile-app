import 'package:flutter/material.dart';

/// Catégorie d'une petite annonce (valeurs de l'API `listing_type`).
enum ListingType {
  sell('sell', 'Vente', Icons.sell_outlined),
  buy('buy', 'Recherche', Icons.search_rounded),
  equipment('equipment', 'Matériel', Icons.handyman_outlined),
  feed('feed', 'Alimentation', Icons.grass_outlined),
  service('service', 'Saillie', Icons.favorite_border_rounded);

  const ListingType(this.api, this.label, this.icon);

  final String api;
  final String label;
  final IconData icon;

  static ListingType fromApi(String? value) => ListingType.values.firstWhere(
    (t) => t.api == value,
    orElse: () => ListingType.sell,
  );
}

/// État d'une annonce (valeurs de l'API `status`).
enum ListingStatus {
  available('available', 'Disponible'),
  reserved('reserved', 'Réservé'),
  closed('closed', 'Vendu / clôturé');

  const ListingStatus(this.api, this.label);

  final String api;
  final String label;

  static ListingStatus fromApi(String? value) => ListingStatus.values
      .firstWhere((s) => s.api == value, orElse: () => ListingStatus.available);
}

/// Petite annonce entre éleveurs : reproducteurs, matériel, alimentation, saillie…
class MarketplaceListing {
  final int id;
  final int sellerId;
  final String sellerName;
  final String? sellerPhone;
  final String title;
  final ListingType type;
  final String description;
  final double? price;
  final String? location;
  final String? photo;
  final ListingStatus status;
  final DateTime createdAt;

  const MarketplaceListing({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    this.sellerPhone,
    required this.title,
    required this.type,
    required this.description,
    this.price,
    this.location,
    this.photo,
    this.status = ListingStatus.available,
    required this.createdAt,
  });

  bool get isAvailable => status == ListingStatus.available;

  factory MarketplaceListing.fromJson(Map<String, dynamic> json) {
    String? text(dynamic v) {
      final s = v?.toString().trim();
      return s == null || s.isEmpty ? null : s;
    }

    return MarketplaceListing(
      id: json['id'] as int,
      sellerId: (json['seller'] as num?)?.toInt() ?? 0,
      sellerName: text(json['seller_name']) ?? 'Éleveur',
      sellerPhone: text(json['seller_phone']),
      title: text(json['title']) ?? '',
      type: ListingType.fromApi(json['listing_type'] as String?),
      description: text(json['description']) ?? '',
      price: json['price'] == null ? null : double.tryParse('${json['price']}'),
      location: text(json['location']),
      photo: text(json['photo']),
      status: ListingStatus.fromApi(json['status'] as String?),
      createdAt:
          DateTime.tryParse('${json['created_at']}')?.toLocal() ??
          DateTime.now(),
    );
  }
}
