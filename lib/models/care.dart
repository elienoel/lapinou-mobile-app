/// Famille d'un type de soin (correspond à `CareTreatment.category` côté API).
enum CareCategory {
  vaccine('vaccine', 'Vaccin', '💉'),
  vitamin('vitamin', 'Vitamine', '🍊'),
  deworming('deworming', 'Déparasitant', '🪱'),
  antiparasitic('antiparasitic', 'Anti-parasitaire externe', '🪰'),
  coccidiosis('coccidiosis', 'Anti-coccidien', '🧪'),
  antibiotic('antibiotic', 'Antibiotique', '💊'),
  other('other', 'Autre', '🩺');

  final String apiValue;
  final String label;
  final String emoji;

  const CareCategory(this.apiValue, this.label, this.emoji);

  static CareCategory fromApi(Object? value) => CareCategory.values.firstWhere(
    (c) => c.apiValue == value?.toString(),
    orElse: () => CareCategory.other,
  );
}

DateTime? _parseDate(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString());

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Libellé d'une durée de renouvellement : « Tous les 6 mois », « Tous les 15 jours »...
String renewalLabel(int? days) {
  if (days == null) return 'Soin ponctuel';
  if (days % 365 == 0) {
    final years = days ~/ 365;
    return years == 1 ? 'Tous les ans' : 'Tous les $years ans';
  }
  if (days % 30 == 0) return 'Tous les ${days ~/ 30} mois';
  if (days % 7 == 0) {
    final weeks = days ~/ 7;
    return weeks == 1 ? 'Toutes les semaines' : 'Toutes les $weeks semaines';
  }
  return days == 1 ? 'Tous les jours' : 'Tous les $days jours';
}

/// Type de soin défini par l'éleveur, avec sa durée avant renouvellement.
class CareTreatment {
  final String id;
  final String name;
  final CareCategory category;

  /// Jours avant de renouveler le soin ; null = soin ponctuel (aucun rappel)
  final int? renewalDays;
  final String? notes;

  /// Nombre de soins enregistrés avec ce type (un type utilisé ne peut pas être supprimé)
  final int recordsCount;

  const CareTreatment({
    required this.id,
    required this.name,
    required this.category,
    this.renewalDays,
    this.notes,
    this.recordsCount = 0,
  });

  factory CareTreatment.fromJson(Map<String, dynamic> json) => CareTreatment(
    id: json['id'].toString(),
    name: json['name']?.toString() ?? '',
    category: CareCategory.fromApi(json['category']),
    renewalDays:
        json['renewal_days'] == null
            ? null
            : int.tryParse(json['renewal_days'].toString()),
    notes: json['notes'],
    recordsCount: int.tryParse('${json['records_count'] ?? 0}') ?? 0,
  );
}

/// Résumé d'un lapin soigné (ou à soigner).
class CareRabbit {
  final String id;
  final String name;
  final String tagNumber;

  const CareRabbit({
    required this.id,
    required this.name,
    required this.tagNumber,
  });

  factory CareRabbit.fromJson(Map<String, dynamic> json) => CareRabbit(
    id: json['id'].toString(),
    name: json['name']?.toString() ?? '',
    tagNumber: json['tag_number']?.toString() ?? '',
  );

  static List<CareRabbit> listFrom(Object? raw) =>
      raw is List
          ? [
            for (final r in raw)
              CareRabbit.fromJson(Map<String, dynamic>.from(r as Map)),
          ]
          : const [];
}

/// Soin effectué : quel traitement, quand, pourquoi et sur quels lapins.
class CareRecord {
  final String id;
  final String treatmentId;
  final String treatmentName;
  final CareCategory category;
  final List<CareRabbit> rabbits;
  final DateTime date;
  final String purpose;
  final DateTime? nextDueDate;
  final String? notes;

  const CareRecord({
    required this.id,
    required this.treatmentId,
    required this.treatmentName,
    required this.category,
    required this.rabbits,
    required this.date,
    this.purpose = '',
    this.nextDueDate,
    this.notes,
  });

  factory CareRecord.fromJson(Map<String, dynamic> json) => CareRecord(
    id: json['id'].toString(),
    treatmentId: json['treatment'].toString(),
    treatmentName: json['treatment_name']?.toString() ?? '',
    category: CareCategory.fromApi(json['treatment_category']),
    rabbits: CareRabbit.listFrom(json['rabbits_detail']),
    date: _parseDate(json['date']) ?? DateTime.now(),
    purpose: json['purpose']?.toString() ?? '',
    nextDueDate: _parseDate(json['next_due_date']),
    notes: json['notes'],
  );
}

/// Urgence d'un rappel : en retard, dans les 7 jours, ou plus tard.
enum DueStatus { overdue, soon, upcoming }

/// Prochain soin à effectuer, avec les lapins concernés par cette échéance.
class UpcomingCare {
  final String recordId;
  final String treatmentId;
  final String treatmentName;
  final CareCategory category;
  final String purpose;
  final DateTime lastDate;
  final DateTime dueDate;

  /// Jours avant l'échéance (négatif = en retard)
  final int daysUntilDue;
  final DueStatus status;
  final List<CareRabbit> rabbits;

  const UpcomingCare({
    required this.recordId,
    required this.treatmentId,
    required this.treatmentName,
    required this.category,
    required this.purpose,
    required this.lastDate,
    required this.dueDate,
    required this.daysUntilDue,
    required this.status,
    required this.rabbits,
  });

  factory UpcomingCare.fromJson(Map<String, dynamic> json) => UpcomingCare(
    recordId: json['record'].toString(),
    treatmentId: json['treatment'].toString(),
    treatmentName: json['treatment_name']?.toString() ?? '',
    category: CareCategory.fromApi(json['treatment_category']),
    purpose: json['purpose']?.toString() ?? '',
    lastDate: _parseDate(json['last_date']) ?? DateTime.now(),
    dueDate: _parseDate(json['due_date']) ?? DateTime.now(),
    daysUntilDue: int.tryParse('${json['days_until_due']}') ?? 0,
    status: switch (json['status']) {
      'overdue' => DueStatus.overdue,
      'soon' => DueStatus.soon,
      _ => DueStatus.upcoming,
    },
    rabbits: CareRabbit.listFrom(json['rabbits']),
  );

  /// « En retard de 3 j », « Aujourd'hui », « Demain », « Dans 5 j »
  String get dueLabel {
    if (daysUntilDue < 0) return 'En retard de ${-daysUntilDue} j';
    if (daysUntilDue == 0) return 'Aujourd\'hui';
    if (daysUntilDue == 1) return 'Demain';
    return 'Dans $daysUntilDue j';
  }
}
