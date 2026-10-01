import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/cage.dart';
import '../models/rabbit.dart';
import '../providers/auth_provider.dart';
import '../providers/rabbit_provider.dart';
import '../services/api_constants.dart';
import '../theme/colors.dart';
import '../widgets/app_icon.dart';

class AddRabbitScreen extends StatefulWidget {
  final Rabbit? initialRabbitToEdit;

  const AddRabbitScreen({super.key, this.initialRabbitToEdit});

  @override
  State<AddRabbitScreen> createState() => _AddRabbitScreenState();
}

class _AddRabbitScreenState extends State<AddRabbitScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _tagController;
  late TextEditingController _cageController;
  late TextEditingController _weightController;
  late TextEditingController _notesController;

  RabbitGender _selectedGender = RabbitGender.female;
  String _selectedBreed = 'Fauve de Bourgogne';
  late String _selectedColor;
  RabbitStatus _selectedStatus = RabbitStatus.active;
  DateTime _birthDate = DateTime.now().subtract(const Duration(days: 180));
  String? _selectedFatherId;
  String? _selectedCageId;
  int? _selectedCompartment;
  String? _selectedMotherId;
  int _avatarColorIndex = 0;
  File? _pickedPhotoFile;
  bool _isSaving = false;

  static const List<String> _commonBreeds = [
    'Fauve de Bourgogne',
    'Géant des Flandres',
    'Néo-Zélandais',
    'Californien',
    'Rex',
    'Papillon Français',
    'Argenté de Champagne',
    'Bélier Français',
    'Chinchilla',
    'Gris du Bourbonnais',
    'Autre / Croisé',
  ];

  static const List<(String, Color)> _coatColors = [
    ('Fauve', Color(0xFFC97A3D)),
    ('Blanc', Color(0xFFF5F5F5)),
    ('Noir', Color(0xFF1A1A1A)),
    ('Gris', Color(0xFF9E9E9E)),
    ('Bleu', Color(0xFF6E7C8C)),
    ('Havane', Color(0xFF6B4226)),
    ('Chinchilla', Color(0xFFB0B7BF)),
    ('Isabelle', Color(0xFFE8D5A9)),
    ('Loutre', Color(0xFF5C4033)),
    ('Marron', Color(0xFF7B3F00)),
    ('Roux', Color(0xFFA0522D)),
    ('Bicolore', Color(0xFFBDBDBD)),
  ];

  @override
  void initState() {
    super.initState();
    final edit = widget.initialRabbitToEdit;
    _nameController = TextEditingController(text: edit?.name ?? '');
    _cageController = TextEditingController(text: edit?.cageNumber ?? '');
    _weightController = TextEditingController(
      text: edit?.weightKg != null ? edit!.weightKg.toString() : '',
    );
    _notesController = TextEditingController(text: edit?.notes ?? '');

    if (edit != null) {
      _selectedGender = edit.gender;
      _selectedBreed =
          _commonBreeds.contains(edit.breed) ? edit.breed : _commonBreeds.first;
      _selectedStatus = edit.status;
      _birthDate = edit.birthDate;
      _selectedFatherId = edit.sireId;
      _selectedCageId = edit.cageId;
      _selectedCompartment = edit.compartmentNumber;
      _selectedMotherId = edit.damId;
      _avatarColorIndex = edit.avatarColorIndex;
    }

    _selectedColor =
        edit != null && _coatColors.any((c) => c.$1 == edit.color)
            ? edit.color
            : _coatColors.first.$1;

    _tagController = TextEditingController(
      text: edit?.tagNumber ?? _generateTagNumber(_selectedBreed),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    _cageController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _breedInitials(String breed) {
    const stopWords = {'de', 'du', 'des', 'le', 'la', 'les', 'et'};
    final words =
        breed
            .split(RegExp(r'[\s/\-]+'))
            .where((w) => w.isNotEmpty && !stopWords.contains(w.toLowerCase()))
            .toList();
    if (words.isEmpty) return 'LP';
    if (words.length == 1) {
      final w = words.first.toUpperCase();
      return w.length >= 2 ? w.substring(0, 2) : '${w}X';
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  String _generateTagNumber(String breed) {
    final rabbits = Provider.of<RabbitProvider>(context, listen: false).rabbits;
    final base = '${_breedInitials(breed)}-${DateTime.now().year}-';
    var maxSeq = 0;
    for (final r in rabbits) {
      if (r.tagNumber.startsWith(base)) {
        final seq = int.tryParse(r.tagNumber.substring(base.length)) ?? 0;
        if (seq > maxSeq) maxSeq = seq;
      }
    }
    return '$base${(maxSeq + 1).toString().padLeft(2, '0')}';
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _pickedPhotoFile = File(picked.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking photo: $e');
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Photo du Lapin',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primarySoft,
                      child: Icon(
                        Icons.camera_alt,
                        color: AppColors.primary,
                      ),
                    ),
                    title: const Text('Prendre une photo'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickPhoto(ImageSource.camera);
                    },
                  ),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primarySoft,
                      child: Icon(
                        Icons.photo_library,
                        color: AppColors.primary,
                      ),
                    ),
                    title: const Text('Choisir dans la galerie'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickPhoto(ImageSource.gallery);
                    },
                  ),
                  if (_pickedPhotoFile != null ||
                      widget.initialRabbitToEdit?.primaryPhotoUrl != null)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                      title: const Text(
                        'Supprimer la photo',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _pickedPhotoFile = null;
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(2018),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _birthDate) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  String _resolveCageNumber(RabbitProvider provider) {
    final cage = provider.getCageById(_selectedCageId);
    if (cage != null && _selectedCompartment != null) {
      return '${cage.name}-$_selectedCompartment';
    }
    final typed = _cageController.text.trim();
    return typed.isEmpty || provider.cages.isNotEmpty ? 'Non assigné' : typed;
  }

  /// Toutes les loges sont sélectionnables : une loge peut accueillir plusieurs lapins.
  List<int> _selectableCompartments(Cage cage) =>
      cage.slots.map((c) => c.number).toList();

  /// Loge proposée par défaut : la première loge libre, sinon la première.
  int? _defaultCompartment(Cage cage) {
    final free = cage.slots.where((c) => c.isFree).firstOrNull;
    return (free ?? cage.slots.firstOrNull)?.number;
  }

  /// Libellé d'une loge avec les lapins qui s'y trouvent déjà (hors lapin édité).
  String _compartmentOption(Cage cage, int number) {
    final editedId = widget.initialRabbitToEdit?.id;
    final others =
        cage.slots
            .firstWhere((c) => c.number == number)
            .occupants
            .where((o) => o.id != editedId)
            .toList();
    final label = cage.compartmentLabel(number);
    if (others.isEmpty) return '$label · libre';
    return '$label · ${others.map((o) => o.name).join(', ')}';
  }

  Widget _buildCageSelector(List<Cage> cages) {
    final cage = cages.where((c) => c.id == _selectedCageId).firstOrNull;
    final compartments = cage == null ? <int>[] : _selectableCompartments(cage);
    return Column(
      children: [
        DropdownButtonFormField<String?>(
          isExpanded: true,
          value: cage?.id,
          decoration: const InputDecoration(
            labelText: 'Cage',
            prefixIcon: Icon(Icons.grid_view, size: 20),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Aucune cage'),
            ),
            for (final c in cages)
              DropdownMenuItem<String?>(
                value: c.id,
                child: Text(
                  'Cage ${c.name} (${c.freeCount}/${c.compartmentsCount} libres)',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (id) {
            setState(() {
              _selectedCageId = id;
              final picked = cages.where((c) => c.id == id).firstOrNull;
              _selectedCompartment =
                  picked == null ? null : _defaultCompartment(picked);
            });
          },
        ),
        if (cage != null) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            isExpanded: true,
            value:
                compartments.contains(_selectedCompartment)
                    ? _selectedCompartment
                    : null,
            decoration: const InputDecoration(
              labelText: 'Loge',
              prefixIcon: Icon(Icons.door_front_door_outlined, size: 20),
            ),
            items: [
              for (final n in compartments)
                DropdownMenuItem(
                  value: n,
                  child: Text(
                    _compartmentOption(cage, n),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (n) => setState(() => _selectedCompartment = n),
            validator: (v) => v == null ? 'Choisissez une loge' : null,
          ),
          // Une lapine qui allaite déménage avec ses lapereaux (non sevrés)
          if (widget.initialRabbitToEdit != null &&
              context.read<RabbitProvider>().nursingKitsOf(
                    widget.initialRabbitToEdit!.id,
                  ) >
                  0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '🍼 Ses ${context.read<RabbitProvider>().nursingKitsOf(widget.initialRabbitToEdit!.id)} lapereaux non sevrés la suivent dans cette loge.',
                key: const ValueKey('kits-follow-note'),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.statusPregnantText,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _saveRabbit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    final provider = Provider.of<RabbitProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final newRabbit = Rabbit(
      id:
          widget.initialRabbitToEdit?.id ??
          'rab-${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      tagNumber: _tagController.text.trim().toUpperCase(),
      gender: _selectedGender,
      breed: _selectedBreed,
      birthDate: _birthDate,
      color: _selectedColor,
      cageNumber: _resolveCageNumber(provider),
      cageId: _selectedCageId,
      compartmentNumber: _selectedCageId == null ? null : _selectedCompartment,
      sireId: _selectedFatherId,
      damId: _selectedMotherId,
      status: _selectedStatus,
      weightKg: double.tryParse(_weightController.text.replaceAll(',', '.')),
      photoUrl: widget.initialRabbitToEdit?.photoUrl,
      images: widget.initialRabbitToEdit?.images ?? const [],
      avatarColorIndex: _avatarColorIndex,
      notes:
          _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
    );

    if (widget.initialRabbitToEdit != null) {
      await provider.updateRabbit(newRabbit, token: auth.token);
      if (_pickedPhotoFile != null) {
        await provider.uploadRabbitPhoto(
          newRabbit.id,
          _pickedPhotoFile!,
          isPrimary: true,
          token: auth.token,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lapin ${newRabbit.name} mis à jour avec succès'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } else {
      await provider.addRabbit(
        newRabbit,
        photoFile: _pickedPhotoFile,
        token: auth.token,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lapin ${newRabbit.name} enregistré avec succès !'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }

    await provider.fetchCages(token: auth.token);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context, newRabbit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RabbitProvider>(context);
    final eligibleFathers = provider.getEligibleFathers(
      excludeId: widget.initialRabbitToEdit?.id,
    );
    final eligibleMothers = provider.getEligibleMothers(
      excludeId: widget.initialRabbitToEdit?.id,
    );

    final isEditing = widget.initialRabbitToEdit != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isEditing ? 'Modifier le Lapin' : 'Nouveau Reproducteur'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Visual Rabbit Avatar selector
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _showPhotoOptions,
                        child: Stack(
                          children: [
                            Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      _selectedGender == RabbitGender.male
                                          ? AppColors.maleBlue
                                          : AppColors.femalePink,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child:
                                    _pickedPhotoFile != null
                                        ? Image.file(
                                          _pickedPhotoFile!,
                                          width: 104,
                                          height: 104,
                                          fit: BoxFit.cover,
                                        )
                                        : (widget
                                                    .initialRabbitToEdit
                                                    ?.primaryPhotoUrl !=
                                                null &&
                                            widget
                                                .initialRabbitToEdit!
                                                .primaryPhotoUrl!
                                                .isNotEmpty)
                                        ? Image.network(
                                          ApiConstants.formatMediaUrl(
                                            widget
                                                .initialRabbitToEdit!
                                                .primaryPhotoUrl,
                                          ),
                                          width: 104,
                                          height: 104,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Center(
                                                    child: AppIcon(
                                                      AppIcons.rabbit,
                                                      size: 56,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                        )
                                        : const Center(
                                          child: AppIcon(
                                            AppIcons.rabbit,
                                            size: 56,
                                            color: AppColors.primary,
                                          ),
                                        ),
                              ),
                            ),
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(40),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _showPhotoOptions,
                        icon: const Icon(
                          Icons.add_a_photo,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        label: Text(
                          _pickedPhotoFile != null ||
                                  (widget
                                          .initialRabbitToEdit
                                          ?.primaryPhotoUrl !=
                                      null)
                              ? 'Modifier la photo'
                              : 'Ajouter une photo',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedGender == RabbitGender.male
                            ? 'Mâle Reproducteur ♂'
                            : 'Femelle Reproductrice ♀',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color:
                              _selectedGender == RabbitGender.male
                                  ? AppColors.maleBlue
                                  : AppColors.femalePink,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Gender Toggle
                _buildSectionTitle('Sexe du Lapin'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildGenderOption(
                        label: 'Femelle ♀',
                        gender: RabbitGender.female,
                        color: AppColors.femalePink,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildGenderOption(
                        label: 'Mâle ♂',
                        gender: RabbitGender.male,
                        color: AppColors.maleBlue,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Name & Tag number
                _buildSectionTitle('Identification'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom ou Surnom *',
                          hintText: 'Ex: Bambou, Bella...',
                          prefixIcon: Icon(Icons.badge_outlined, size: 20),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Veuillez saisir un nom';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: TextFormField(
                        controller: _tagController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Matricule / Bague',
                          prefixIcon: Icon(Icons.tag, size: 20),
                          helperText: 'Généré automatiquement',
                          helperMaxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Breed
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedBreed,
                  decoration: const InputDecoration(
                    labelText: 'Race *',
                    prefixIcon: Icon(Icons.pets, size: 20),
                  ),
                  items:
                      _commonBreeds.map((b) {
                        return DropdownMenuItem(
                          value: b,
                          child: Text(b, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _selectedBreed = val;
                      if (widget.initialRabbitToEdit == null) {
                        _tagController.text = _generateTagNumber(val);
                      }
                    });
                  },
                ),

                const SizedBox(height: 16),

                // Color
                _buildSectionTitle('Robe / Couleur'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _coatColors
                          .map((c) => _buildColorOption(c.$1, c.$2))
                          .toList(),
                ),

                const SizedBox(height: 16),

                // Cage & loge
                Builder(
                  builder: (context) {
                    final cages = context.watch<RabbitProvider>().cages;
                    if (cages.isEmpty) {
                      return TextFormField(
                        controller: _cageController,
                        decoration: const InputDecoration(
                          labelText: 'N° Cage / Clapier',
                          hintText: 'Ex: A-04',
                          prefixIcon: Icon(Icons.grid_view, size: 20),
                        ),
                      );
                    }
                    return _buildCageSelector(cages);
                  },
                ),

                const SizedBox(height: 16),

                // Weight
                TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Poids (kg)',
                    hintText: 'Ex: 4.2',
                    suffixText: 'kg',
                    prefixIcon: Icon(Icons.scale, size: 20),
                  ),
                ),

                const SizedBox(height: 16),

                // Birth date selector
                InkWell(
                  onTap: _pickBirthDate,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.cake_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Date de naissance',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat(
                                    'dd MMMM yyyy',
                                    'fr_FR',
                                  ).format(_birthDate),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.edit_calendar,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Genealogy / Pedigree Parents selector
                _buildSectionTitle('Filiation & Arbre Généalogique'),
                const SizedBox(height: 4),
                const Text(
                  'Sélectionnez les géniteurs pour relier automatiquement ce lapin à sa famille et son arbre généalogique.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),

                // Father selector
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  value: _selectedFatherId,
                  decoration: InputDecoration(
                    labelText: 'Père ♂',
                    prefixIcon: const Icon(
                      Icons.male,
                      color: AppColors.maleBlue,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Inconnu / Souche externe'),
                    ),
                    ...eligibleFathers.map((f) {
                      return DropdownMenuItem<String?>(
                        value: f.id,
                        child: Text(
                          '${f.name} (${f.tagNumber} - ${f.breed})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedFatherId = val);
                  },
                ),

                const SizedBox(height: 12),

                // Mother selector
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  value: _selectedMotherId,
                  decoration: InputDecoration(
                    labelText: 'Mère ♀',
                    prefixIcon: const Icon(
                      Icons.female,
                      color: AppColors.femalePink,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Inconnue / Souche externe'),
                    ),
                    ...eligibleMothers.map((m) {
                      return DropdownMenuItem<String?>(
                        value: m.id,
                        child: Text(
                          '${m.name} (${m.tagNumber} - ${m.breed})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedMotherId = val);
                  },
                ),

                const SizedBox(height: 20),

                // Status
                _buildSectionTitle('Statut Actuel'),
                const SizedBox(height: 8),
                DropdownButtonFormField<RabbitStatus>(
                  isExpanded: true,
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Statut du reproducteur',
                    prefixIcon: Icon(Icons.shield_outlined, size: 20),
                  ),
                  items:
                      RabbitStatus.values.map((s) {
                        String label = 'Actif';
                        if (s == RabbitStatus.pregnant) label = 'En gestation';
                        if (s == RabbitStatus.lactating) {
                          label = 'En allaitement';
                        }
                        if (s == RabbitStatus.resting) label = 'Au repos';
                        if (s == RabbitStatus.retired) label = 'Réformé';
                        return DropdownMenuItem(value: s, child: Text(label));
                      }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatus = val);
                  },
                ),

                const SizedBox(height: 16),

                // Notes
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes & Observations',
                    hintText:
                        'Docilité, antécédents médicaux, particularités du pelage...',
                    alignLabelWithHint: true,
                  ),
                ),

                const SizedBox(height: 30),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveRabbit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    child:
                        _isSaving
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                            : Text(
                              isEditing
                                  ? 'Mettre à jour le lapin'
                                  : 'Enregistrer le lapin',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildColorOption(String label, Color swatch) {
    final isSelected = _selectedColor == label;
    return InkWell(
      onTap: () => setState(() => _selectedColor = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(25) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: swatch,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cardBorder, width: 1),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderOption({
    required String label,
    required RabbitGender gender,
    required Color color,
  }) {
    final isSelected = _selectedGender == gender;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedGender = gender;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isSelected ? AppColors.onPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
