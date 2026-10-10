import 'dart:math' as math;

/// Où en est une portée : au nid, sevrage à confirmer (date prévue dépassée), ou entièrement sevrée.
enum LitterStatus { nursing, weaningDue, weaned }

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Litter {
  /// Âge (en jours) auquel le sevrage est prévu par défaut
  static const int defaultWeaningDays = 45;

  final String id;
  final String? matingId;
  final String motherId;
  final String? fatherId;
  final DateTime birthDate;
  final int bornAlive;
  final int stillBorn;

  /// Lapereaux morts au nid avant le sevrage
  final int diedCount;

  /// Total cumulé de lapereaux sevrés (le sevrage peut se faire en plusieurs fois)
  final int? weanedCount;

  /// Date du dernier sevrage effectué
  final DateTime? weanedAt;

  /// Date PRÉVUE de sevrage (~45 jours)
  final DateTime? weaningDate;
  final String? notes;

  const Litter({
    required this.id,
    this.matingId,
    required this.motherId,
    this.fatherId,
    required this.birthDate,
    required this.bornAlive,
    this.stillBorn = 0,
    this.diedCount = 0,
    this.weanedCount,
    this.weanedAt,
    this.weaningDate,
    this.notes,
  });

  int get totalBorn => bornAlive + stillBorn;

  int get weaned => weanedCount ?? 0;

  /// Lapereaux encore au nid : nés vivants, ni sevrés ni morts.
  int get kitsRemaining => math.max(bornAlive - weaned - diedCount, 0);

  /// Âge de la portée en jours (0 le jour de la naissance).
  int get ageDays =>
      _dateOnly(DateTime.now()).difference(_dateOnly(birthDate)).inDays;

  DateTime get calculatedWeaningDate =>
      weaningDate ?? birthDate.add(const Duration(days: defaultWeaningDays));

  /// Jours avant la date prévue de sevrage ; négatif quand elle est dépassée.
  int get daysUntilWeaning =>
      _dateOnly(
        calculatedWeaningDate,
      ).difference(_dateOnly(DateTime.now())).inDays;

  LitterStatus get status {
    if (kitsRemaining == 0) return LitterStatus.weaned;
    return daysUntilWeaning <= 0
        ? LitterStatus.weaningDue
        : LitterStatus.nursing;
  }

  /// Plus aucun lapereau à sevrer (le sevrage se confirme à la main, il ne se déduit plus de la date).
  bool get isWeaned => status == LitterStatus.weaned;

  /// Avancement vers la date de sevrage prévue, de 0 (naissance) à 1.
  double get weaningProgress {
    final total =
        _dateOnly(
          calculatedWeaningDate,
        ).difference(_dateOnly(birthDate)).inDays;
    return total <= 0 ? 1.0 : (ageDays / total).clamp(0.0, 1.0);
  }

  Litter copyWith({
    int? bornAlive,
    int? stillBorn,
    int? diedCount,
    DateTime? weaningDate,
    String? notes,
    bool clearNotes = false,
  }) {
    return Litter(
      id: id,
      matingId: matingId,
      motherId: motherId,
      fatherId: fatherId,
      birthDate: birthDate,
      bornAlive: bornAlive ?? this.bornAlive,
      stillBorn: stillBorn ?? this.stillBorn,
      diedCount: diedCount ?? this.diedCount,
      weanedCount: weanedCount,
      weanedAt: weanedAt,
      weaningDate: weaningDate ?? this.weaningDate,
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }

  static int _int(dynamic v, [int fallback = 0]) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? fallback;

  factory Litter.fromJson(Map<String, dynamic> json) {
    DateTime parsedBirthDate = DateTime.now();
    if (json['birth_date'] != null) {
      parsedBirthDate =
          DateTime.tryParse(json['birth_date'].toString()) ?? DateTime.now();
    }

    DateTime? parsedWeaningDate;
    if (json['weaning_date'] != null) {
      parsedWeaningDate = DateTime.tryParse(json['weaning_date'].toString());
    }
    DateTime? parsedWeanedAt;
    if (json['weaned_at'] != null) {
      parsedWeanedAt = DateTime.tryParse(json['weaned_at'].toString());
    }

    return Litter(
      id: json['id'].toString(),
      matingId: json['mating']?.toString(),
      motherId: json['mother'] != null ? json['mother'].toString() : '',
      fatherId: json['father']?.toString(),
      birthDate: parsedBirthDate,
      bornAlive: _int(json['born_alive']),
      stillBorn: _int(json['still_born']),
      diedCount: _int(json['died_count']),
      weanedCount:
          json['weaned_count'] == null ? null : _int(json['weaned_count']),
      weanedAt: parsedWeanedAt,
      weaningDate: parsedWeaningDate,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (matingId != null) 'mating': int.tryParse(matingId!) ?? matingId,
      'mother': int.tryParse(motherId) ?? motherId,
      if (fatherId != null) 'father': int.tryParse(fatherId!) ?? fatherId,
      'birth_date': _isoDate(birthDate),
      'born_alive': bornAlive,
      'still_born': stillBorn,
      'died_count': diedCount,
      if (weaningDate != null) 'weaning_date': _isoDate(weaningDate!),
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }

  /// Champs modifiables d'une portée existante (le sevrage passe par [RabbitProvider.weanLitter]).
  Map<String, dynamic> toEditJson() => {
    'born_alive': bornAlive,
    'still_born': stillBorn,
    'died_count': diedCount,
    if (weaningDate != null) 'weaning_date': _isoDate(weaningDate!),
    'notes': notes ?? '',
  };
}
