enum RabbitGender { male, female }

enum RabbitStatus { active, pregnant, lactating, resting, retired }

class RabbitImageModel {
  final int id;
  final int rabbitId;
  final String imageUrl;
  final String? caption;
  final bool isPrimary;
  final DateTime? createdAt;

  const RabbitImageModel({
    required this.id,
    required this.rabbitId,
    required this.imageUrl,
    this.caption,
    this.isPrimary = false,
    this.createdAt,
  });

  factory RabbitImageModel.fromJson(Map<String, dynamic> json) {
    return RabbitImageModel(
      id:
          json['id'] is int
              ? json['id']
              : int.tryParse(json['id'].toString()) ?? 0,
      rabbitId:
          json['rabbit'] is int
              ? json['rabbit']
              : int.tryParse(json['rabbit'].toString()) ?? 0,
      imageUrl: json['image']?.toString() ?? '',
      caption: json['caption'],
      isPrimary: json['is_primary'] == true,
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rabbit': rabbitId,
      'image': imageUrl,
      'caption': caption,
      'is_primary': isPrimary,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}

class Rabbit {
  final String id;
  final String name;
  final String tagNumber;
  final RabbitGender gender;
  final String breed;
  final DateTime birthDate;
  final String color;
  final String cageNumber;
  final String? cageId;
  final int? compartmentNumber;
  final String? sireId; // Father ID
  final String? damId; // Mother ID
  final RabbitStatus status;
  final double? weightKg;
  final String? photoUrl;
  final List<RabbitImageModel> images;
  final int avatarColorIndex;
  final String? notes;

  /// Lapereaux encore au nid avec cette lapine (non sevrés) : ils la suivent quand on la déplace
  final int nursingKits;

  const Rabbit({
    required this.id,
    required this.name,
    required this.tagNumber,
    required this.gender,
    required this.breed,
    required this.birthDate,
    required this.color,
    required this.cageNumber,
    this.cageId,
    this.compartmentNumber,
    this.sireId,
    this.damId,
    this.status = RabbitStatus.active,
    this.weightKg,
    this.photoUrl,
    this.images = const [],
    this.avatarColorIndex = 0,
    this.notes,
    this.nursingKits = 0,
  });

  bool get isMale => gender == RabbitGender.male;
  bool get isFemale => gender == RabbitGender.female;

  String get genderSymbol => isMale ? '♂ Mâle' : '♀ Femelle';
  String get shortGenderSymbol => isMale ? '♂' : '♀';

  String get statusLabel {
    switch (status) {
      case RabbitStatus.active:
        return 'Reproducteur actif';
      case RabbitStatus.pregnant:
        return 'En gestation';
      case RabbitStatus.lactating:
        return 'En allaitement';
      case RabbitStatus.resting:
        return 'Au repos';
      case RabbitStatus.retired:
        return 'Réformé';
    }
  }

  String get ageString {
    final now = DateTime.now();
    final difference = now.difference(birthDate).inDays;
    final months = (difference / 30.44).floor();
    if (months < 1) {
      return '$difference j';
    } else if (months < 12) {
      return '$months mois';
    } else {
      final years = (months / 12).floor();
      final remainingMonths = months % 12;
      if (remainingMonths == 0) {
        return '$years an${years > 1 ? 's' : ''}';
      }
      return '$years an ${remainingMonths}m';
    }
  }

  String? get primaryPhotoUrl {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return photoUrl;
    }
    final primaryImg = images.where((img) => img.isPrimary).firstOrNull;
    if (primaryImg != null && primaryImg.imageUrl.isNotEmpty) {
      return primaryImg.imageUrl;
    }
    if (images.isNotEmpty && images.first.imageUrl.isNotEmpty) {
      return images.first.imageUrl;
    }
    return null;
  }

  Rabbit copyWith({
    String? id,
    String? name,
    String? tagNumber,
    RabbitGender? gender,
    String? breed,
    DateTime? birthDate,
    String? color,
    String? cageNumber,
    String? cageId,
    int? compartmentNumber,
    bool clearCage = false,
    String? sireId,
    String? damId,
    RabbitStatus? status,
    double? weightKg,
    String? photoUrl,
    List<RabbitImageModel>? images,
    int? avatarColorIndex,
    String? notes,
    int? nursingKits,
  }) {
    return Rabbit(
      id: id ?? this.id,
      name: name ?? this.name,
      tagNumber: tagNumber ?? this.tagNumber,
      gender: gender ?? this.gender,
      breed: breed ?? this.breed,
      birthDate: birthDate ?? this.birthDate,
      color: color ?? this.color,
      cageNumber: cageNumber ?? this.cageNumber,
      cageId: clearCage ? null : (cageId ?? this.cageId),
      compartmentNumber:
          clearCage ? null : (compartmentNumber ?? this.compartmentNumber),
      sireId: sireId ?? this.sireId,
      damId: damId ?? this.damId,
      status: status ?? this.status,
      weightKg: weightKg ?? this.weightKg,
      photoUrl: photoUrl ?? this.photoUrl,
      images: images ?? this.images,
      avatarColorIndex: avatarColorIndex ?? this.avatarColorIndex,
      notes: notes ?? this.notes,
      nursingKits: nursingKits ?? this.nursingKits,
    );
  }

  factory Rabbit.fromJson(Map<String, dynamic> json) {
    RabbitGender g = RabbitGender.male;
    final rawGender = (json['gender'] ?? '').toString().toUpperCase();
    if (rawGender == 'F' || rawGender == 'FEMALE' || rawGender == 'FEMELLE') {
      g = RabbitGender.female;
    }

    RabbitStatus s = RabbitStatus.active;
    final rawStatus = (json['status'] ?? '').toString().toLowerCase();
    switch (rawStatus) {
      case 'pregnant':
        s = RabbitStatus.pregnant;
        break;
      case 'lactating':
        s = RabbitStatus.lactating;
        break;
      case 'resting':
        s = RabbitStatus.resting;
        break;
      case 'retired':
        s = RabbitStatus.retired;
        break;
      default:
        s = RabbitStatus.active;
    }

    DateTime parsedBirthDate = DateTime.now();
    if (json['birth_date'] != null) {
      parsedBirthDate =
          DateTime.tryParse(json['birth_date'].toString()) ?? DateTime.now();
    }

    double? parsedWeight;
    if (json['weight_kg'] != null) {
      parsedWeight = double.tryParse(json['weight_kg'].toString());
    }

    List<RabbitImageModel> parsedImages = [];
    if (json['images'] is List) {
      parsedImages =
          (json['images'] as List)
              .map((img) => RabbitImageModel.fromJson(img))
              .toList();
    }

    return Rabbit(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      tagNumber: json['tag_number'] ?? '',
      gender: g,
      breed:
          json['breed_name'] ??
          (json['breed'] is Map ? json['breed']['name'] : 'Fauve de Bourgogne'),
      birthDate: parsedBirthDate,
      color: json['color'] ?? 'Standard',
      cageNumber: json['cage_number'] ?? 'Non assigné',
      cageId: json['cage']?.toString(),
      compartmentNumber: json['compartment_number'] as int?,
      sireId: json['sire']?.toString(),
      damId: json['dam']?.toString(),
      status: s,
      weightKg: parsedWeight,
      photoUrl: json['photo'],
      images: parsedImages,
      avatarColorIndex:
          json['avatar_color_index'] is int ? json['avatar_color_index'] : 0,
      notes: json['notes'],
      nursingKits: json['nursing_kits'] is int ? json['nursing_kits'] : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'tag_number': tagNumber,
      'gender': gender == RabbitGender.male ? 'M' : 'F',
      'birth_date':
          '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
      'color': color,
      'cage_number': cageNumber,
      // Repli sur l'id local (non numérique) si la cage/le parent n'a pas encore
      // été synchronisé·e : ça permet à SyncService de détecter la référence non
      // résolue et de différer l'envoi, plutôt que de silencieusement l'omettre.
      'cage': cageId == null ? null : (int.tryParse(cageId!) ?? cageId),
      'compartment_number': cageId == null ? null : compartmentNumber,
      'sire': sireId == null ? null : (int.tryParse(sireId!) ?? sireId),
      'dam': damId == null ? null : (int.tryParse(damId!) ?? damId),
      'status': status.name,
      if (weightKg != null) 'weight_kg': weightKg,
      'avatar_color_index': avatarColorIndex,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }
}
