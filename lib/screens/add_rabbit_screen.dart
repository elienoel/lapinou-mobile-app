import '../widgets/app_ui.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/cage.dart';
import '../models/rabbit.dart';
import '../providers/auth_provider.dart';
import '../providers/rabbit_provider.dart';
import '../services/api_constants.dart';
import '../theme/colors.dart';
import '../widgets/cage_diagram.dart';
import '../widgets/wave_edge.dart';
import '../widgets/plan_limit.dart';

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
  String? _selectedBreedId;
  String _selectedBreedName = 'Fauve de Bourgogne';
  late String _selectedColor;
  RabbitStatus _selectedStatus = RabbitStatus.active;
  DateTime _birthDate = DateTime.now().subtract(const Duration(days: 180));

  /// Faux tant que la date n'a pas été choisie (nouveau lapin) : on affiche
  /// alors le placeholder, et elle est demandée avant de passer à l'étape 2.
  late bool _birthDateSet = widget.initialRabbitToEdit != null;
  bool _birthDateError = false;
  String? _selectedFatherId;
  String? _selectedCageId;
  int? _selectedCompartment;
  String? _selectedMotherId;
  int _avatarColorIndex = 0;
  int _step = 0;
  File? _pickedPhotoFile;
  bool _isSaving = false;

  static const List<(String, String)> _coatColors = [
    ('Fauve', 'assets/colors/fauve.webp'),
    ('Blanc', 'assets/colors/blanc.webp'),
    ('Noir', 'assets/colors/noir.webp'),
    ('Gris', 'assets/colors/gris.webp'),
    ('Bicolore Noir', 'assets/colors/bicolore_noir.webp'),
    ('Bicolore Roux', 'assets/colors/bicolore_roux.webp'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<RabbitProvider>(context, listen: false).fetchBreeds(
          token: Provider.of<AuthProvider>(context, listen: false).token,
        );
      }
    });
    final edit = widget.initialRabbitToEdit;
    _nameController = TextEditingController(text: edit?.name ?? '');
    _cageController = TextEditingController(text: edit?.cageNumber ?? '');
    _weightController = TextEditingController(
      text: edit?.weightKg != null ? edit!.weightKg.toString() : '',
    );
    _notesController = TextEditingController(text: edit?.notes ?? '');

    if (edit != null) {
      _selectedGender = edit.gender;
      _selectedBreedId = edit.breedId;
      _selectedBreedName = edit.breed;
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
      text: edit?.tagNumber ?? _generateTagNumber(_selectedBreedName),
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
                      child: Icon(Icons.camera_alt, color: AppColors.primary),
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

    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthDateSet = true;
        _birthDateError = false;
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

  /// Étape 3 : choix de la cage, puis de la loge directement sur son schéma.
  Widget _buildCagePicker(List<Cage> cages) {
    final cage = cages.where((c) => c.id == _selectedCageId).firstOrNull;
    final editedId = widget.initialRabbitToEdit?.id;
    final provider = context.read<RabbitProvider>();
    final kits = editedId == null ? 0 : provider.nursingKitsOf(editedId);

    Widget choice({
      required Key key,
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          key: key,
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.secondaryTint,
          side: BorderSide.none,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
          shape: const StadiumBorder(),
        ),
      );
    }

    Widget diagram(Cage c) {
      final d = CageDiagram(
        cage: c,
        highlightedCompartment: _selectedCompartment,
        onCompartmentTap:
            (slot) => setState(() => _selectedCompartment = slot.number),
      );
      if (c.columnsCount <= 2) return d;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: c.columnsCount * 190.0, child: d),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              choice(
                key: const ValueKey('cage-choice-none'),
                label: 'Aucune cage',
                selected: cage == null,
                onTap:
                    () => setState(() {
                      _selectedCageId = null;
                      _selectedCompartment = null;
                    }),
              ),
              for (final c in cages)
                choice(
                  key: ValueKey('cage-choice-${c.id}'),
                  label:
                      'Cage ${c.name} · ${c.freeCount}/${c.compartmentsCount} libres',
                  selected: c.id == cage?.id,
                  onTap:
                      () => setState(() {
                        _selectedCageId = c.id;
                        _selectedCompartment = _defaultCompartment(c);
                      }),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (cage == null)
          const Text(
            'Le lapin ne sera placé dans aucune cage pour le moment.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          )
        else ...[
          const Text(
            'Touchez la loge où placer ce lapin.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          diagram(cage),
          const SizedBox(height: 14),
          // Loge retenue, avec les lapins qui y sont déjà
          Container(
            key: const ValueKey('selected-compartment'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.secondaryTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.door_front_door_outlined,
                  size: 20,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedCompartment == null
                        ? 'Aucune loge choisie'
                        : _compartmentOption(cage, _selectedCompartment!),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Une lapine qui allaite déménage avec ses lapereaux (non sevrés)
          if (kits > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Ses $kits lapereaux non sevrés la suivent dans cette loge.',
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

  void _showError(String message) {
    showAppSnack(context, message, error: true);
  }

  Future<void> _saveRabbit() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? true)) {
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      // Le nom est saisi à la 1re étape
      setState(() => _step = 0);
      _showError('Veuillez saisir un nom');
      return;
    }

    // Création seulement : une modification ne change pas le nombre de lapins
    if (widget.initialRabbitToEdit == null &&
        !await guardRabbitQuota(context, 1)) {
      return;
    }
    if (!mounted) return;
    final provider = Provider.of<RabbitProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final tag = _tagController.text.trim().toUpperCase();
    final editingId = widget.initialRabbitToEdit?.id;
    final tagTaken = provider.rabbits.any(
      (r) => r.id != editingId && r.tagNumber.toUpperCase() == tag,
    );
    if (_selectedCageId != null && _selectedCompartment == null) {
      _showError('Indiquez la loge de la cage.');
      return;
    }
    if (_selectedCageId == null && _selectedCompartment != null) {
      _showError("Sélectionnez d'abord une cage.");
      return;
    }
    if (tagTaken) {
      showAppSnack(
        context,
        'La bague $tag est déjà utilisée dans votre élevage.',
        error: true,
      );
      return;
    }

    setState(() => _isSaving = true);

    final newRabbit = Rabbit(
      id:
          widget.initialRabbitToEdit?.id ??
          'rab-${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      tagNumber: _tagController.text.trim().toUpperCase(),
      gender: _selectedGender,
      breed: _selectedBreedName,
      breedId: _selectedBreedId,
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
        showAppSnack(context, 'Lapin ${newRabbit.name} mis à jour avec succès');
      }
    } else {
      await provider.addRabbit(
        newRabbit,
        photoFile: _pickedPhotoFile,
        token: auth.token,
      );
      if (mounted) {
        showAppSnack(
          context,
          'Lapin ${newRabbit.name} enregistré avec succès !',
        );
      }
    }

    await provider.fetchCages(token: auth.token);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context, newRabbit);
    }
  }

  // ---- Assistant en 3 étapes ----

  static const _stepTitles = ['Identité', 'Race & origines', 'Emplacement'];

  /// Passe à l'étape suivante si celle-ci est complète.
  void _next() {
    final formOk = _formKey.currentState?.validate() ?? true;
    final dateOk = _step != 0 || _birthDateSet;
    if (!dateOk) setState(() => _birthDateError = true);
    if (!formOk || !dateOk) return;
    FocusScope.of(context).unfocus();
    setState(() => _step++);
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _step--);
    }
  }

  /// « 6 mois », « 1 an et 2 mois » : âge à partir de la date de naissance.
  String _ageLabel(DateTime birth) {
    final now = DateTime.now();
    var months = (now.year - birth.year) * 12 + now.month - birth.month;
    if (now.day < birth.day) months--;
    if (months < 1) {
      final days = now.difference(birth).inDays;
      return '$days jour${days > 1 ? 's' : ''}';
    }
    final years = months ~/ 12;
    final rest = months % 12;
    if (years == 0) return '$months mois';
    final y = '$years an${years > 1 ? 's' : ''}';
    return rest == 0 ? y : '$y et $rest mois';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialRabbitToEdit != null;
    final topInset = MediaQuery.of(context).padding.top;
    final onViolet = _step == 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        // Le retour du téléphone revient à l'étape précédente
        canPop: _step == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          backgroundColor: AppColors.secondary,
          body: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildWizardHeader(isEditing, topInset),
                Expanded(
                  child:
                      onViolet
                          ? SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                            child: _buildIdentityStep(),
                          )
                          // Haut violet, bas blanc, avec la vague entre les deux
                          : Container(
                            color: Colors.white,
                            child: Column(
                              children: [
                                const WaveEdge(color: AppColors.secondary),
                                Expanded(
                                  child: SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      12,
                                      20,
                                      24,
                                    ),
                                    child:
                                        _step == 1
                                            ? _buildOriginsStep()
                                            : _buildPlacementStep(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                ),
                _buildWizardFooter(isEditing, onViolet),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// En-tête violet : retour, titre, étape courante et barre de progression.
  Widget _buildWizardHeader(bool isEditing, double topInset) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, topInset + 4, 20, _step == 0 ? 16 : 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: _step == 0 ? 'Fermer' : 'Étape précédente',
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 20,
                  color: Colors.white,
                ),
                onPressed: _back,
              ),
              Expanded(
                child: Text(
                  isEditing ? 'Modifier le lapin' : 'Nouveau lapin',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                'Étape ${_step + 1}/3',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withAlpha(200),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _stepTitles[_step],
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 5,
                          decoration: BoxDecoration(
                            color:
                                i <= _step
                                    ? Colors.white
                                    : Colors.white.withAlpha(70),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Boutons du bas : « Retour » (à partir de l'étape 2) et « Suivant »,
  /// ou « Enregistrer » à la dernière étape.
  Widget _buildWizardFooter(bool isEditing, bool onViolet) {
    final isLast = _step == 2;
    const shape = StadiumBorder();
    const textStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w800);

    final next = FilledButton(
      key: ValueKey(isLast ? 'wizard-save' : 'wizard-next'),
      onPressed: _isSaving ? null : (isLast ? _saveRabbit : _next),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: shape,
        textStyle: textStyle,
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
              : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      isLast
                          ? (isEditing ? 'Mettre à jour' : 'Enregistrer')
                          : 'Suivant',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isLast) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ],
              ),
    );

    return Container(
      color: onViolet ? AppColors.secondary : Colors.white,
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            if (_step > 0) ...[
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('wizard-back'),
                  onPressed: _isSaving ? null : _back,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                    shape: shape,
                    textStyle: textStyle,
                    minimumSize: const Size.fromHeight(54),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 20),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Retour',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: _step > 0 ? 2 : 1,
              child: SizedBox(height: 54, child: next),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Étape 1 : photo, nom, date de naissance (sur le violet) ----

  Widget _buildIdentityStep() {
    final existingPhoto = widget.initialRabbitToEdit?.primaryPhotoUrl;
    final hasPhoto =
        _pickedPhotoFile != null ||
        (existingPhoto != null && existingPhoto.isNotEmpty);
    // Cadre : 85 % de la largeur de l'écran, au format 2,1:1
    final frameWidth = MediaQuery.of(context).size.width * 0.85;
    final frameHeight = frameWidth / 2.1;

    Widget photoContent;
    if (_pickedPhotoFile != null) {
      photoContent = Image.file(_pickedPhotoFile!, fit: BoxFit.cover);
    } else if (hasPhoto) {
      photoContent = Image.network(
        ApiConstants.formatMediaUrl(existingPhoto),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _photoPlaceholder(),
      );
    } else {
      photoContent = _photoPlaceholder();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cadre photo
        Center(
          child: Column(
            children: [
              GestureDetector(
                key: const ValueKey('photo-frame'),
                onTap: _showPhotoOptions,
                child: Container(
                  width: frameWidth,
                  height: frameHeight,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(28),
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                      color: Colors.white.withAlpha(150),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(30),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(29),
                    child: SizedBox.expand(child: photoContent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _showPhotoOptions,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: Text(
                  hasPhoto ? 'Changer la photo' : 'Ajouter une photo',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Nom : gros texte, sans bordure ni label, sur le violet
        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          cursorColor: Colors.white,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
          decoration: InputDecoration(
            hintText: 'Nom du lapin',
            hintStyle: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white.withAlpha(80),
            ),
            filled: true,
            fillColor: Colors.transparent,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            errorStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFFD2D2),
            ),
          ),
          validator:
              (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Veuillez saisir un nom'
                      : null,
        ),
        const SizedBox(height: 24),

        // Date de naissance : même style, ouvre le calendrier
        InkWell(
          key: const ValueKey('birth-date'),
          onTap: _pickBirthDate,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _birthDateSet
                        ? DateFormat('d MMMM yyyy', 'fr_FR').format(_birthDate)
                        : 'Date de naissance',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color:
                          _birthDateSet
                              ? Colors.white
                              : Colors.white.withAlpha(80),
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Icon(
                  Icons.edit_calendar_outlined,
                  color: Colors.white.withAlpha(200),
                ),
              ],
            ),
          ),
        ),
        if (_birthDateSet)
          Text(
            _ageLabel(_birthDate),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(180),
            ),
          )
        else if (_birthDateError)
          const Text(
            'Choisissez la date de naissance',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFFD2D2),
            ),
          ),
      ],
    );
  }

  Widget _photoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_a_photo_outlined,
          size: 52,
          color: Colors.white.withAlpha(220),
        ),
        const SizedBox(height: 8),
        Text(
          'Photo du lapin',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white.withAlpha(190),
          ),
        ),
      ],
    );
  }

  // ---- Étape 2 : sexe, race, couleur, parents ----

  Widget _buildOriginsStep() {
    final provider = context.watch<RabbitProvider>();
    final eligibleFathers = provider.getEligibleFathers(
      excludeId: widget.initialRabbitToEdit?.id,
    );
    final eligibleMothers = provider.getEligibleMothers(
      excludeId: widget.initialRabbitToEdit?.id,
    );
    final breeds = provider.breeds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Sexe'),
        const SizedBox(height: 10),
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

        _buildSectionTitle('Race'),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: breeds.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == breeds.length) {
                return _buildBreedCard(
                  name: 'Autre / Croisé',
                  imageUrl: null,
                  selected: _selectedBreedId == null,
                  onTap: () => _selectBreed(null, 'Autre / Croisé'),
                );
              }
              final b = breeds[index];
              return _buildBreedCard(
                name: b.name,
                imageUrl: b.imageUrl,
                selected: _selectedBreedId == b.id,
                onTap: () => _selectBreed(b.id, b.name),
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        _buildSectionTitle('Robe / Couleur'),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: _coatColors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final c = _coatColors[index];
              return _buildColorCard(
                name: c.$1,
                imageAsset: c.$2,
                selected: _selectedColor == c.$1,
                onTap: () => setState(() => _selectedColor = c.$1),
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        _buildSectionTitle('Parents'),
        const SizedBox(height: 4),
        const Text(
          'Reliez ce lapin à sa famille et à son arbre généalogique.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          isExpanded: true,
          value: _selectedFatherId,
          decoration: const InputDecoration(
            labelText: 'Père ♂',
            prefixIcon: Icon(Icons.male, color: AppColors.maleBlue),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Inconnu / Souche externe'),
            ),
            for (final f in eligibleFathers)
              DropdownMenuItem<String?>(
                value: f.id,
                child: Text(
                  '${f.name} (${f.tagNumber} - ${f.breed})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (val) => setState(() => _selectedFatherId = val),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          isExpanded: true,
          value: _selectedMotherId,
          decoration: const InputDecoration(
            labelText: 'Mère ♀',
            prefixIcon: Icon(Icons.female, color: AppColors.femalePink),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Inconnue / Souche externe'),
            ),
            for (final m in eligibleMothers)
              DropdownMenuItem<String?>(
                value: m.id,
                child: Text(
                  '${m.name} (${m.tagNumber} - ${m.breed})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (val) => setState(() => _selectedMotherId = val),
        ),
        const SizedBox(height: 12),

        // Champs secondaires, repliés pour garder l'étape légère
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const ValueKey('more-info'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            initiallyExpanded: widget.initialRabbitToEdit != null,
            title: _buildSectionTitle('Autres informations'),
            subtitle: const Text(
              'Poids, statut et notes',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            children: [
              TextFormField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Poids (kg)',
                  hintText: 'Ex : 4.2',
                  suffixText: 'kg',
                  prefixIcon: Icon(Icons.scale, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RabbitStatus>(
                isExpanded: true,
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Statut',
                  prefixIcon: Icon(Icons.shield_outlined, size: 20),
                ),
                items: [
                  for (final s in RabbitStatus.values)
                    DropdownMenuItem(
                      value: s,
                      child: Text(switch (s) {
                        RabbitStatus.pregnant => 'En gestation',
                        RabbitStatus.lactating => 'En allaitement',
                        RabbitStatus.resting => 'Au repos',
                        RabbitStatus.retired => 'Réformé',
                        _ => 'Actif',
                      }),
                    ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedStatus = val);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes & observations',
                  hintText:
                      'Docilité, antécédents, particularités du pelage...',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- Étape 3 : cage et loge ----

  Widget _buildPlacementStep() {
    final cages = context.watch<RabbitProvider>().cages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Cage'),
        const SizedBox(height: 12),
        if (cages.isEmpty)
          TextFormField(
            controller: _cageController,
            decoration: const InputDecoration(
              labelText: 'N° Cage / Clapier',
              hintText: 'Ex : A-04',
              prefixIcon: Icon(Icons.grid_view, size: 20),
            ),
          )
        else
          _buildCagePicker(cages),
      ],
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

  void _selectBreed(String? breedId, String breedName) {
    setState(() {
      _selectedBreedId = breedId;
      _selectedBreedName = breedName;
      if (widget.initialRabbitToEdit == null) {
        _tagController.text = _generateTagNumber(breedName);
      }
    });
  }

  /// Carte de sélection partagée par la race et la couleur (même gabarit :
  /// nom en haut à gauche, vignette ancrée en bas à droite).
  Widget _buildPickerCard({
    Key? key,
    required String name,
    required bool selected,
    required VoidCallback onTap,
    required Widget thumbnail,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 140,
        height: 80,
        padding: const EdgeInsets.only(left: 12, top: 10, right: 10, bottom: 3),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.secondaryTint,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(10),
            topRight: const Radius.circular(30),
            bottomLeft: const Radius.circular(0),
            bottomRight: const Radius.circular(10),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              right: 40,
              child: Text(
                name,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            Positioned(
              bottom: -5,
              right: -10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: thumbnail,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickerIconFallback(bool selected) {
    return Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? Colors.white.withAlpha(35) : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? Colors.white : AppColors.cardBorder,
        ),
      ),
      child: Icon(
        Icons.pets,
        color: selected ? Colors.white : AppColors.primary,
        size: 24,
      ),
    );
  }

  Widget _buildBreedCard({
    required String name,
    required String? imageUrl,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return _buildPickerCard(
      key: ValueKey('breed-${imageUrl ?? name}'),
      name: name,
      selected: selected,
      onTap: onTap,
      thumbnail:
          imageUrl != null
              ? Image.network(
                ApiConstants.formatMediaUrl(imageUrl),
                width: 80,
                height: 58,
                fit: BoxFit.fitHeight,
                errorBuilder: (_, __, ___) => _pickerIconFallback(selected),
              )
              : _pickerIconFallback(selected),
    );
  }

  Widget _buildColorCard({
    required String name,
    required String imageAsset,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return _buildPickerCard(
      key: ValueKey('color-$imageAsset'),
      name: name,
      selected: selected,
      onTap: onTap,
      thumbnail: Image.asset(
        imageAsset,
        width: 80,
        height: 80,
        fit: BoxFit.fitHeight,
      ),
    );
  }

  /// Choix du sexe : pastille pleine dans la couleur du sexe quand elle est choisie.
  Widget _buildGenderOption({
    required String label,
    required RabbitGender gender,
    required Color color,
  }) {
    final isSelected = _selectedGender == gender;
    return InkWell(
      key: ValueKey('gender-${gender.name}'),
      onTap: () => setState(() => _selectedGender = gender),
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withAlpha(20),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isSelected ? color : color.withAlpha(90)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}
