import 'rabbit.dart';

/// Lapin logé dans une loge (résumé renvoyé par l'API des cages).
class CageOccupant {
  final String id;
  final String name;
  final String tagNumber;
  final RabbitGender gender;
  final RabbitStatus status;
  final String? photoUrl;

  /// Lapereaux non sevrés qui vivent avec cette lapine
  final int nursingKits;

  const CageOccupant({
    required this.id,
    required this.name,
    required this.tagNumber,
    required this.gender,
    this.status = RabbitStatus.active,
    this.photoUrl,
    this.nursingKits = 0,
  });

  bool get isMale => gender == RabbitGender.male;

  factory CageOccupant.fromJson(Map<String, dynamic> json) {
    return CageOccupant(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      tagNumber: json['tag_number'] ?? '',
      gender:
          (json['gender'] ?? '').toString().toUpperCase() == 'F'
              ? RabbitGender.female
              : RabbitGender.male,
      status: RabbitStatus.values.firstWhere(
        (s) => s.name == (json['status'] ?? '').toString(),
        orElse: () => RabbitStatus.active,
      ),
      photoUrl: json['photo'],
      nursingKits: json['nursing_kits'] is int ? json['nursing_kits'] : 0,
    );
  }
}

/// Une loge d'une cage, numérotée de haut en bas (1 = loge du haut).
/// Une loge peut accueillir plusieurs lapins.
class CageCompartment {
  final int number;

  /// Tous les lapins logés dans cette loge (vide = loge libre).
  final List<CageOccupant> occupants;

  /// [occupant] reste accepté pour une loge à un seul lapin ; [occupants] prime s'il est fourni.
  CageCompartment({
    required this.number,
    CageOccupant? occupant,
    List<CageOccupant>? occupants,
  }) : occupants = occupants ?? (occupant == null ? const [] : [occupant]);

  /// Premier lapin de la loge, s'il y en a un.
  CageOccupant? get occupant => occupants.isEmpty ? null : occupants.first;

  bool get isFree => occupants.isEmpty;

  /// Lapereaux non sevrés présents dans la loge (avec leur mère)
  int get kitsCount => occupants.fold(0, (sum, o) => sum + o.nursingKits);
}

class Cage {
  final String id;
  final String name;
  final String? location;
  final int rowsCount;
  final int columnsCount;
  final String? notes;
  final List<CageCompartment> compartments;

  static const int maxRows = 12;
  static const int maxColumns = 6;

  const Cage({
    required this.id,
    required this.name,
    required this.rowsCount,
    this.columnsCount = 1,
    this.location,
    this.notes,
    this.compartments = const [],
  });

  int get compartmentsCount => rowsCount * columnsCount;

  /// Loges de la cage (numérotées ligne par ligne, de haut en bas puis de
  /// gauche à droite) ; à défaut de détail renvoyé par l'API, toutes libres.
  List<CageCompartment> get slots =>
      compartments.length == compartmentsCount
          ? compartments
          : List.generate(
            compartmentsCount,
            (i) => CageCompartment(number: i + 1),
          );

  /// Loge située à la [row] et [column] données (1-indexées).
  CageCompartment slotAt(int row, int column) =>
      slots[(row - 1) * columnsCount + (column - 1)];

  /// Libellé lisible d'une loge, avec sa position quand la cage a plusieurs colonnes.
  String compartmentLabel(int number) {
    if (columnsCount == 1) return 'Loge $number';
    final row = (number - 1) ~/ columnsCount + 1;
    final column = (number - 1) % columnsCount + 1;
    return 'Loge $number (ligne $row, colonne $column)';
  }

  /// Nombre de loges occupées (une loge partagée par plusieurs lapins ne compte qu'une fois).
  int get occupiedCount => slots.where((c) => !c.isFree).length;

  /// Nombre total de lapins logés dans la cage.
  int get rabbitsCount => slots.fold(0, (sum, c) => sum + c.occupants.length);

  /// Lapereaux non sevrés présents dans la cage.
  int get kitsCount => slots.fold(0, (sum, c) => sum + c.kitsCount);
  int get freeCount => compartmentsCount - occupiedCount;
  bool get isFull => freeCount == 0;

  static int _int(dynamic v, int fallback) =>
      v is int ? v : int.tryParse('$v') ?? fallback;

  factory Cage.fromJson(Map<String, dynamic> json) {
    final compartments =
        json['compartments'] is List
            ? (json['compartments'] as List).map((c) {
              // `rabbits` liste tous les lapins de la loge ; `rabbit` (ancien format) le premier
              final list =
                  c['rabbits'] is List
                      ? (c['rabbits'] as List)
                          .whereType<Map>()
                          .map(
                            (r) => CageOccupant.fromJson(
                              Map<String, dynamic>.from(r),
                            ),
                          )
                          .toList()
                      : (c['rabbit'] is Map
                          ? [
                            CageOccupant.fromJson(
                              Map<String, dynamic>.from(c['rabbit']),
                            ),
                          ]
                          : <CageOccupant>[]);
              return CageCompartment(
                number: c['number'] as int,
                occupants: list,
              );
            }).toList()
            : <CageCompartment>[];
    return Cage(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      location: json['location'],
      rowsCount: _int(json['rows_count'], 1),
      columnsCount: _int(json['columns_count'], 1),
      notes: json['notes'],
      compartments: compartments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'rows_count': rowsCount,
      'columns_count': columnsCount,
      'location': location ?? '',
      'notes': notes ?? '',
    };
  }
}
