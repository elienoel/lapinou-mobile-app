enum MatingStatus {
  pending, // Accouplement récent, en attente de palpation
  confirmed, // Gestation confirmée
  kindled, // Mise bas effectuée
  failed, // Non gestante / saut infructueux
}

class Mating {
  final String id;
  final String maleId;
  final String femaleId;
  final DateTime matingDate;
  final MatingStatus status;
  final String? notes;

  /// Date à laquelle la palpation a été effectuée (null tant qu'elle n'est pas confirmée)
  final DateTime? palpationDoneAt;

  /// Une mise bas ne peut pas être enregistrée moins de 21 jours après la saillie
  static const int minGestationDays = 21;

  const Mating({
    required this.id,
    required this.maleId,
    required this.femaleId,
    required this.matingDate,
    this.status = MatingStatus.pending,
    this.notes,
    this.palpationDoneAt,
  });

  Mating copyWith({
    String? maleId,
    String? femaleId,
    DateTime? matingDate,
    MatingStatus? status,
    String? notes,
    bool clearNotes = false,
    DateTime? palpationDoneAt,
  }) {
    return Mating(
      id: id,
      maleId: maleId ?? this.maleId,
      femaleId: femaleId ?? this.femaleId,
      matingDate: matingDate ?? this.matingDate,
      status: status ?? this.status,
      notes: clearNotes ? null : (notes ?? this.notes),
      palpationDoneAt: palpationDoneAt ?? this.palpationDoneAt,
    );
  }

  /// Gestation en cours (pas encore de mise bas ni d'échec)
  bool get isActive =>
      status == MatingStatus.pending || status == MatingStatus.confirmed;

  bool get palpationDone =>
      status == MatingStatus.confirmed || palpationDoneAt != null;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Jours écoulés depuis la saillie (jours calendaires)
  int get daysSinceMating =>
      _day(DateTime.now()).difference(_day(matingDate)).inDays;

  /// Première date à laquelle la mise bas peut être enregistrée (saillie + 21 jours)
  DateTime get earliestKindlingDate =>
      _day(matingDate).add(const Duration(days: minGestationDays));

  /// La mise bas ne peut être enregistrée qu'à partir de 21 jours après la saillie
  bool get canRegisterKindling =>
      isActive && daysSinceMating >= minGestationDays;

  /// Date estimée de palpation (12 jours après le saut)
  DateTime get palpationDate => matingDate.add(const Duration(days: 12));

  /// Date de pose de la boîte à nid (28 jours après le saut)
  DateTime get nestBoxDate => matingDate.add(const Duration(days: 28));

  /// Date estimée de mise bas (31 jours en moyenne)
  DateTime get expectedKindlingDate => matingDate.add(const Duration(days: 31));

  /// Nombre de jours restants avant la mise bas
  int get daysUntilKindling {
    final now = DateTime.now();
    return expectedKindlingDate.difference(now).inDays;
  }

  /// Est-ce que la boîte à nid doit déjà être installée ?
  bool get shouldInstallNestBox {
    return DateTime.now().isAfter(nestBoxDate);
  }

  /// Jour de gestation actuel (1 à 31+)
  int get gestationDay {
    return DateTime.now().difference(matingDate).inDays + 1;
  }

  String get statusLabel {
    switch (status) {
      case MatingStatus.pending:
        return 'En attente palpation (J$gestationDay)';
      case MatingStatus.confirmed:
        return 'Gestante confirmée (J$gestationDay)';
      case MatingStatus.kindled:
        return 'Mise bas réalisée';
      case MatingStatus.failed:
        return 'Infructueux';
    }
  }

  factory Mating.fromJson(Map<String, dynamic> json) {
    MatingStatus s = MatingStatus.pending;
    final rawStatus = (json['status'] ?? '').toString().toLowerCase();
    switch (rawStatus) {
      case 'confirmed':
        s = MatingStatus.confirmed;
        break;
      case 'kindled':
        s = MatingStatus.kindled;
        break;
      case 'failed':
        s = MatingStatus.failed;
        break;
      default:
        s = MatingStatus.pending;
    }

    DateTime parsedMatingDate = DateTime.now();
    if (json['mating_date'] != null) {
      parsedMatingDate =
          DateTime.tryParse(json['mating_date'].toString()) ?? DateTime.now();
    }

    return Mating(
      id: json['id'].toString(),
      maleId: json['male'] != null ? json['male'].toString() : '',
      femaleId: json['female'] != null ? json['female'].toString() : '',
      matingDate: parsedMatingDate,
      status: s,
      notes: json['notes'],
      palpationDoneAt:
          json['palpation_done_at'] != null
              ? DateTime.tryParse(json['palpation_done_at'].toString())
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'male': int.tryParse(maleId) ?? maleId,
      'female': int.tryParse(femaleId) ?? femaleId,
      'mating_date':
          '${matingDate.year.toString().padLeft(4, '0')}-${matingDate.month.toString().padLeft(2, '0')}-${matingDate.day.toString().padLeft(2, '0')}',
      'status': status.name,
      'notes': notes ?? '',
    };
  }
}
