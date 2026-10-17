/// Catégorie d'un médicament du catalogue pharmacie (référentiel partagé, pas propre
/// à l'utilisateur — voir [MedicationCategory] vs `CareCategory` qui sert au suivi des
/// soins déjà administrés à un lapin, un concept distinct).
enum MedicationCategory {
  vaccine('vaccine', 'Vaccin'),
  antibiotic('antibiotic', 'Antibiotique'),
  antiparasitic('antiparasitic', 'Anti-parasitaire'),
  vitamin('vitamin', 'Vitamine'),
  digestive('digestive', 'Digestif'),
  other('other', 'Autre');

  final String apiValue;
  final String label;

  const MedicationCategory(this.apiValue, this.label);

  static MedicationCategory fromApi(Object? value) =>
      MedicationCategory.values.firstWhere(
        (c) => c.apiValue == value?.toString(),
        orElse: () => MedicationCategory.other,
      );
}

/// Pharmacie telle que listée dans le détail d'un médicament : pas de prix ici
/// (le prix exact n'apparaît que sur la fiche de la pharmacie elle-même).
class MedicationPharmacy {
  final String id;
  final String name;
  final String address;
  final String? phone;
  final double latitude;
  final double longitude;

  MedicationPharmacy({
    required this.id,
    required this.name,
    required this.address,
    this.phone,
    required this.latitude,
    required this.longitude,
  });

  factory MedicationPharmacy.fromJson(Map<String, dynamic> json) =>
      MedicationPharmacy(
        id: json['id'].toString(),
        name: json['name']?.toString() ?? '',
        address: json['address']?.toString() ?? '',
        phone: json['phone']?.toString(),
        latitude: double.tryParse(json['latitude'].toString()) ?? 0,
        longitude: double.tryParse(json['longitude'].toString()) ?? 0,
      );
}

class Medication {
  final String id;
  final String name;
  final MedicationCategory category;
  final String? description;
  final String? image;

  /// Fourchette de prix observée chez les pharmacies qui le vendent ; `null` si
  /// aucune pharmacie ne le vend encore.
  final double? priceMin;
  final double? priceMax;

  /// Pharmacies qui le vendent (vide depuis la grille catalogue, rempli au détail).
  final List<MedicationPharmacy> pharmacies;

  Medication({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    this.image,
    this.priceMin,
    this.priceMax,
    this.pharmacies = const [],
  });

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
    id: json['id'].toString(),
    name: json['name']?.toString() ?? '',
    category: MedicationCategory.fromApi(json['category']),
    description: json['description']?.toString(),
    image: json['image']?.toString(),
    priceMin:
        json['price_min'] == null
            ? null
            : double.tryParse(json['price_min'].toString()),
    priceMax:
        json['price_max'] == null
            ? null
            : double.tryParse(json['price_max'].toString()),
    pharmacies:
        json['pharmacies'] is List
            ? (json['pharmacies'] as List)
                .map(
                  (e) =>
                      MedicationPharmacy.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
            : const [],
  );
}
