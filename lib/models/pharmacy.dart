import 'medication.dart';

/// Médicament vendu par une pharmacie, avec le prix exact pratiqué par celle-ci.
class PharmacyMedicationPrice {
  final String medicationId;
  final String medicationName;
  final MedicationCategory medicationCategory;
  final String? medicationImage;
  final double price;

  PharmacyMedicationPrice({
    required this.medicationId,
    required this.medicationName,
    required this.medicationCategory,
    this.medicationImage,
    required this.price,
  });

  factory PharmacyMedicationPrice.fromJson(Map<String, dynamic> json) =>
      PharmacyMedicationPrice(
        medicationId: json['medication_id'].toString(),
        medicationName: json['medication_name']?.toString() ?? '',
        medicationCategory: MedicationCategory.fromApi(
          json['medication_category'],
        ),
        medicationImage: json['medication_image']?.toString(),
        price: double.tryParse(json['price'].toString()) ?? 0,
      );
}

class Pharmacy {
  final String id;
  final String name;
  final String address;
  final String? phone;
  final double latitude;
  final double longitude;

  /// Médicaments vendus avec leur prix exact (vide depuis la carte/liste, rempli au détail).
  final List<PharmacyMedicationPrice> medications;

  Pharmacy({
    required this.id,
    required this.name,
    required this.address,
    this.phone,
    required this.latitude,
    required this.longitude,
    this.medications = const [],
  });

  factory Pharmacy.fromJson(Map<String, dynamic> json) => Pharmacy(
    id: json['id'].toString(),
    name: json['name']?.toString() ?? '',
    address: json['address']?.toString() ?? '',
    phone: json['phone']?.toString(),
    latitude: double.tryParse(json['latitude'].toString()) ?? 0,
    longitude: double.tryParse(json['longitude'].toString()) ?? 0,
    medications:
        json['medications'] is List
            ? (json['medications'] as List)
                .map(
                  (e) => PharmacyMedicationPrice.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
            : const [],
  );
}
