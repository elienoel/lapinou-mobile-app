enum CareType {
  vaccine, // VHD1, VHD2, Myxomatose
  deworming, // Vermifuge
  antiparasitic, // Traitement gale / puces / tiques
  coccidiosis, // Prévention coccidiose
  checkup, // Bilan santé général
  other,
}

class CareEvent {
  final String id;
  final String rabbitId;
  final CareType type;
  final String title;
  final DateTime date;
  final DateTime? reminderDate;
  final bool isCompleted;
  final String? notes;

  const CareEvent({
    required this.id,
    required this.rabbitId,
    required this.type,
    required this.title,
    required this.date,
    this.reminderDate,
    this.isCompleted = true,
    this.notes,
  });

  String get typeLabel {
    switch (type) {
      case CareType.vaccine:
        return 'Vaccination';
      case CareType.deworming:
        return 'Vermifuge';
      case CareType.antiparasitic:
        return 'Anti-parasitaire';
      case CareType.coccidiosis:
        return 'Coccidiose';
      case CareType.checkup:
        return 'Contrôle';
      case CareType.other:
        return 'Soin';
    }
  }

  factory CareEvent.fromJson(Map<String, dynamic> json) {
    CareType t = CareType.other;
    final rawType = (json['care_type'] ?? '').toString().toLowerCase();
    switch (rawType) {
      case 'vaccine':
        t = CareType.vaccine;
        break;
      case 'deworming':
        t = CareType.deworming;
        break;
      case 'antiparasitic':
        t = CareType.antiparasitic;
        break;
      case 'coccidiosis':
        t = CareType.coccidiosis;
        break;
      case 'checkup':
        t = CareType.checkup;
        break;
      default:
        t = CareType.other;
    }

    DateTime parsedDate = DateTime.now();
    if (json['date'] != null) {
      parsedDate = DateTime.tryParse(json['date'].toString()) ?? DateTime.now();
    }

    DateTime? parsedReminderDate;
    if (json['reminder_date'] != null) {
      parsedReminderDate = DateTime.tryParse(json['reminder_date'].toString());
    }

    return CareEvent(
      id: json['id'].toString(),
      rabbitId: json['rabbit'] != null ? json['rabbit'].toString() : '',
      type: t,
      title: json['title'] ?? '',
      date: parsedDate,
      reminderDate: parsedReminderDate,
      isCompleted: json['is_completed'] == true,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rabbit': int.tryParse(rabbitId) ?? rabbitId,
      'care_type': type.name,
      'title': title,
      'date':
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      if (reminderDate != null)
        'reminder_date':
            '${reminderDate!.year.toString().padLeft(4, '0')}-${reminderDate!.month.toString().padLeft(2, '0')}-${reminderDate!.day.toString().padLeft(2, '0')}',
      'is_completed': isCompleted,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }
}
