import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration personnalisée des délais d'élevage et des rappels de notifications.
class BreedingSettings {
  /// Durée de gestation avant mise bas (par défaut 31 jours, biologique standard : 28 à 34 jours)
  final int gestationDays;

  /// Jour auquel la palpation doit être réalisée (par défaut J12 après la saillie, usuel : 10 à 14 jours)
  final int palpationDays;

  /// Nombre de jours avant la mise bas pour poser la boîte à nid (par défaut 3 jours avant mise bas, soit J28)
  final int nestBoxDaysBeforeKindling;

  /// Âge des lapereaux au sevrage (par défaut 45 jours, usuel : 30 à 60 jours)
  final int weaningDays;

  // ---- Délais d'anticipation pour les notifications ----
  /// Prévenir X jours avant la palpation (0 = le jour même, ou 1, 2 jours avant)
  final int palpationNoticeDays;

  /// Prévenir X jours avant la pose de la boîte à nid (0 = le jour même)
  final int nestBoxNoticeDays;

  /// Prévenir X jours avant la mise bas (par défaut 1 jour avant)
  final int kindlingNoticeDays;

  /// Prévenir X jours avant le sevrage (par défaut 3 jours avant)
  final int weaningNoticeDays;

  /// Heure du rappel de notification le matin (ex: 8 = 08h00)
  final int notificationHour;

  const BreedingSettings({
    this.gestationDays = 31,
    this.palpationDays = 12,
    this.nestBoxDaysBeforeKindling = 3,
    this.weaningDays = 45,
    this.palpationNoticeDays = 0,
    this.nestBoxNoticeDays = 0,
    this.kindlingNoticeDays = 1,
    this.weaningNoticeDays = 3,
    this.notificationHour = 8,
  });

  /// Jour calendaire de la pose de la boîte à nid après la saillie
  int get nestBoxDaysAfterMating =>
      (gestationDays - nestBoxDaysBeforeKindling).clamp(1, gestationDays);

  /// Alias pratique pour le jour du cycle
  int get nestBoxDayOfCycle => nestBoxDaysAfterMating;

  BreedingSettings copyWith({
    int? gestationDays,
    int? palpationDays,
    int? nestBoxDaysBeforeKindling,
    int? weaningDays,
    int? palpationNoticeDays,
    int? nestBoxNoticeDays,
    int? kindlingNoticeDays,
    int? weaningNoticeDays,
    int? notificationHour,
  }) {
    return BreedingSettings(
      gestationDays: gestationDays ?? this.gestationDays,
      palpationDays: palpationDays ?? this.palpationDays,
      nestBoxDaysBeforeKindling:
          nestBoxDaysBeforeKindling ?? this.nestBoxDaysBeforeKindling,
      weaningDays: weaningDays ?? this.weaningDays,
      palpationNoticeDays: palpationNoticeDays ?? this.palpationNoticeDays,
      nestBoxNoticeDays: nestBoxNoticeDays ?? this.nestBoxNoticeDays,
      kindlingNoticeDays: kindlingNoticeDays ?? this.kindlingNoticeDays,
      weaningNoticeDays: weaningNoticeDays ?? this.weaningNoticeDays,
      notificationHour: notificationHour ?? this.notificationHour,
    );
  }

  Map<String, dynamic> toJson() => {
    'gestation_days': gestationDays,
    'palpation_days': palpationDays,
    'nest_box_days_before': nestBoxDaysBeforeKindling,
    'weaning_days': weaningDays,
    'palpation_notice_days': palpationNoticeDays,
    'nest_box_notice_days': nestBoxNoticeDays,
    'kindling_notice_days': kindlingNoticeDays,
    'weaning_notice_days': weaningNoticeDays,
    'notification_hour': notificationHour,
  };

  Map<String, dynamic> toMap() => toJson();

  factory BreedingSettings.fromMap(Map<String, dynamic> map) =>
      BreedingSettings.fromJson(map);

  factory BreedingSettings.fromJson(Map<String, dynamic> json) {
    return BreedingSettings(
      gestationDays: (json['gestation_days'] as num?)?.toInt() ?? 31,
      palpationDays: (json['palpation_days'] as num?)?.toInt() ?? 12,
      nestBoxDaysBeforeKindling:
          (json['nest_box_days_before'] as num?)?.toInt() ?? 3,
      weaningDays: (json['weaning_days'] as num?)?.toInt() ?? 45,
      palpationNoticeDays:
          (json['palpation_notice_days'] as num?)?.toInt() ?? 0,
      nestBoxNoticeDays: (json['nest_box_notice_days'] as num?)?.toInt() ?? 0,
      kindlingNoticeDays:
          (json['kindling_notice_days'] as num?)?.toInt() ?? 1,
      weaningNoticeDays: (json['weaning_notice_days'] as num?)?.toInt() ?? 3,
      notificationHour: (json['notification_hour'] as num?)?.toInt() ?? 8,
    );
  }

  static const BreedingSettings defaults = BreedingSettings();
}

/// Provider gérant les paramètres d'élevage et de rappels.
class BreedingSettingsProvider with ChangeNotifier {
  static const String _storageKey = 'clapin_breeding_settings';

  BreedingSettings _settings = BreedingSettings.defaults;
  bool _loaded = false;

  BreedingSettings get settings => _settings;
  bool get isLoaded => _loaded;

  BreedingSettingsProvider() {
    load();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_storageKey);
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        _settings = BreedingSettings.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('Erreur chargement paramètres d\'élevage: $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> updateSettings(BreedingSettings newSettings) async {
    _settings = newSettings;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(newSettings.toJson()));
    } catch (e) {
      debugPrint('Erreur sauvegarde paramètres d\'élevage: $e');
    }
  }

  Future<void> resetToDefaults() async {
    await updateSettings(BreedingSettings.defaults);
  }

  void setForTesting(BreedingSettings testSettings) {
    _settings = testSettings;
    _loaded = true;
    notifyListeners();
  }
}
