import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/care.dart';
import '../models/rabbit.dart';
import '../providers/rabbit_provider.dart';
import '../theme/colors.dart';
import 'app_icon.dart';

const _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
);

/// Feuille « Type de soin » : nom, famille et durée avant renouvellement.
/// [existing] non nul = modification. Renvoie true quand le type a été enregistré.
Future<bool?> showCareTreatmentSheet(
  BuildContext context, {
  CareTreatment? existing,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: _sheetShape,
    builder: (ctx) => CareTreatmentSheet(existing: existing),
  );
}

/// Feuille « Enregistrer un soin » : type de soin, date, motif et lapins soignés.
/// [existing] = modification d'un soin ; [treatmentId], [rabbitIds] et [purpose] préremplissent
/// le formulaire (ex. renouvellement depuis un rappel). Renvoie true quand le soin a été enregistré.
Future<bool?> showCareRecordSheet(
  BuildContext context, {
  CareRecord? existing,
  String? treatmentId,
  List<String> rabbitIds = const [],
  String? purpose,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: _sheetShape,
    builder:
        (ctx) => CareRecordSheet(
          existing: existing,
          initialTreatmentId: treatmentId,
          initialRabbitIds: rabbitIds,
          initialPurpose: purpose,
        ),
  );
}

class CareTreatmentSheet extends StatefulWidget {
  final CareTreatment? existing;

  const CareTreatmentSheet({super.key, this.existing});

  @override
  State<CareTreatmentSheet> createState() => _CareTreatmentSheetState();
}

class _CareTreatmentSheetState extends State<CareTreatmentSheet> {
  // Durées usuelles proposées en un clic ; « Ponctuel » = pas de renouvellement
  static const _presets = <(String, int?)>[
    ('Ponctuel', null),
    ('1 semaine', 7),
    ('15 jours', 15),
    ('1 mois', 30),
    ('3 mois', 90),
    ('6 mois', 180),
    ('1 an', 365),
  ];

  late final TextEditingController _name;
  late final TextEditingController _days;
  late final TextEditingController _notes;
  late CareCategory _category;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _name = TextEditingController(text: t?.name ?? '');
    _days = TextEditingController(text: t?.renewalDays?.toString() ?? '');
    _notes = TextEditingController(text: t?.notes ?? '');
    _category = t?.category ?? CareCategory.vaccine;
  }

  @override
  void dispose() {
    _name.dispose();
    _days.dispose();
    _notes.dispose();
    super.dispose();
  }

  int? get _renewalDays => int.tryParse(_days.text.trim());

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Donnez un nom à ce soin.');
      return;
    }
    final raw = _days.text.trim();
    if (raw.isNotEmpty && (_renewalDays == null || _renewalDays! < 1)) {
      setState(() => _error = 'La durée doit être un nombre de jours (1 ou plus).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await context.read<RabbitProvider>().saveCareTreatment(
      id: widget.existing?.id,
      name: name,
      category: _category,
      renewalDays: raw.isEmpty ? null : _renewalDays,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEdit ? 'Modifier le type de soin' : 'Nouveau type de soin',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('treatment-name'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nom du soin',
                hintText: 'Vaccin VHD2, Vitamine ADE, Ivermectine…',
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Famille',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in CareCategory.values)
                  ChoiceChip(
                    key: ValueKey('treatment-category-${c.apiValue}'),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CareCategoryIcon(
                          c,
                          size: 16,
                          color:
                              _category == c
                                  ? Colors.white
                                  : AppColors.textPrimary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(c.label, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    selected: _category == c,
                    selectedColor: AppColors.primary,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color:
                          _category == c ? Colors.white : AppColors.textPrimary,
                    ),
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Durée avant renouvellement',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final (label, days) in _presets)
                  ChoiceChip(
                    key: ValueKey('treatment-preset-${days ?? 'none'}'),
                    label: Text(label),
                    selected: _renewalDays == days,
                    selectedColor: AppColors.primary,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color:
                          _renewalDays == days
                              ? Colors.white
                              : AppColors.textPrimary,
                    ),
                    onSelected:
                        (_) => setState(() => _days.text = days?.toString() ?? ''),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('treatment-days'),
              controller: _days,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Jours avant le prochain soin',
                helperText: 'Laissez vide pour un soin ponctuel (aucun rappel).',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('treatment-notes'),
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (produit, dosage…)',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                key: const ValueKey('treatment-error'),
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                key: const ValueKey('treatment-submit'),
                onPressed: _saving ? null : _submit,
                child:
                    _saving
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : Text(isEdit ? 'Enregistrer' : 'Créer le type de soin'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CareRecordSheet extends StatefulWidget {
  final CareRecord? existing;
  final String? initialTreatmentId;
  final List<String> initialRabbitIds;
  final String? initialPurpose;

  const CareRecordSheet({
    super.key,
    this.existing,
    this.initialTreatmentId,
    this.initialRabbitIds = const [],
    this.initialPurpose,
  });

  @override
  State<CareRecordSheet> createState() => _CareRecordSheetState();
}

class _CareRecordSheetState extends State<CareRecordSheet> {
  late final TextEditingController _purpose;
  late final TextEditingController _notes;
  final TextEditingController _search = TextEditingController();
  late DateTime _date;
  String? _treatmentId;
  late final Set<String> _rabbitIds;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _purpose = TextEditingController(
      text: r?.purpose ?? widget.initialPurpose ?? '',
    );
    _notes = TextEditingController(text: r?.notes ?? '');
    _date = r?.date ?? DateTime.now();
    _treatmentId = r?.treatmentId ?? widget.initialTreatmentId;
    _rabbitIds = {
      if (r != null) ...r.rabbits.map((x) => x.id) else ...widget.initialRabbitIds,
    };
  }

  @override
  void dispose() {
    _purpose.dispose();
    _notes.dispose();
    _search.dispose();
    super.dispose();
  }

  CareTreatment? _treatment(RabbitProvider provider) {
    for (final t in provider.careTreatments) {
      if (t.id == _treatmentId) return t;
    }
    return null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _newTreatment() async {
    final provider = context.read<RabbitProvider>();
    final known = {for (final t in provider.careTreatments) t.id};
    final created = await showCareTreatmentSheet(context);
    if (created != true || !mounted) return;
    // Le type qui vient d'être créé est sélectionné d'office
    final fresh = provider.careTreatments.where((t) => !known.contains(t.id));
    if (fresh.isNotEmpty) setState(() => _treatmentId = fresh.first.id);
  }

  Future<void> _submit() async {
    if (_treatmentId == null) {
      setState(() => _error = 'Choisissez le type de soin effectué.');
      return;
    }
    if (_rabbitIds.isEmpty) {
      setState(() => _error = 'Sélectionnez au moins un lapin soigné.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await context.read<RabbitProvider>().saveCareRecord(
      id: widget.existing?.id,
      treatmentId: _treatmentId!,
      rabbitIds: _rabbitIds.toList(),
      date: _date,
      purpose: _purpose.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RabbitProvider>();
    final treatments = provider.careTreatments;
    final treatment = _treatment(provider);
    final isEdit = widget.existing != null;

    // Lapins réformés exclus, sauf s'ils font déjà partie de ce soin
    final query = _search.text.trim().toLowerCase();
    final rabbits =
        provider.rabbits
            .where(
              (r) =>
                  (r.status != RabbitStatus.retired ||
                      _rabbitIds.contains(r.id)) &&
                  (query.isEmpty ||
                      r.name.toLowerCase().contains(query) ||
                      r.tagNumber.toLowerCase().contains(query)),
            )
            .toList();

    final nextDue =
        treatment?.renewalDays == null
            ? null
            : DateTime(_date.year, _date.month, _date.day + treatment!.renewalDays!);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEdit ? 'Modifier le soin' : 'Enregistrer un soin',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            if (treatments.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.statusPregnantBg,
                  border: Border.all(color: AppColors.statusPregnantText),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Créez d\'abord un type de soin (vaccin, vitamine…).',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('record-new-treatment'),
                      onPressed: _newTreatment,
                      child: const Text('Créer'),
                    ),
                  ],
                ),
              )
            else ...[
              DropdownButtonFormField<String>(
                key: const ValueKey('record-treatment'),
                value: _treatmentId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Type de soin'),
                items: [
                  for (final t in treatments)
                    DropdownMenuItem(
                      value: t.id,
                      child: Row(
                        children: [
                          CareCategoryIcon(
                            t.category,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(t.name, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _treatmentId = v),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const ValueKey('record-new-treatment'),
                  onPressed: _newTreatment,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nouveau type de soin'),
                ),
              ),
            ],
            const SizedBox(height: 4),
            InkWell(
              key: const ValueKey('record-date'),
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date du soin',
                  prefixIcon: Icon(Icons.event_outlined, size: 20),
                ),
                child: Text(DateFormat('dd/MM/yyyy').format(_date)),
              ),
            ),
            if (treatment != null) ...[
              const SizedBox(height: 6),
              Text(
                nextDue == null
                    ? 'Soin ponctuel : aucun rappel.'
                    : '${renewalLabel(treatment.renewalDays)} · prochain soin le '
                        '${DateFormat('dd/MM/yyyy').format(nextDue)}',
                key: const ValueKey('record-next-due'),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('record-purpose'),
              controller: _purpose,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Pour quel motif ?',
                hintText: 'Prévention VHD, toux, gale des oreilles…',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Lapins soignés (${_rabbitIds.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey('record-select-all'),
                  onPressed:
                      () => setState(
                        () => _rabbitIds.addAll(rabbits.map((r) => r.id)),
                      ),
                  child: const Text('Tous'),
                ),
                TextButton(
                  key: const ValueKey('record-select-none'),
                  onPressed: () => setState(_rabbitIds.clear),
                  child: const Text('Aucun'),
                ),
              ],
            ),
            if (provider.rabbits.length > 6)
              TextField(
                key: const ValueKey('record-search'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Rechercher un lapin (nom ou bague)',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                ),
              ),
            const SizedBox(height: 6),
            if (rabbits.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Aucun lapin à afficher.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  color: AppColors.backgroundGrey,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: rabbits.length,
                  itemBuilder: (context, i) {
                    final r = rabbits[i];
                    return CheckboxListTile(
                      key: ValueKey('record-rabbit-${r.id}'),
                      dense: true,
                      activeColor: AppColors.primary,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _rabbitIds.contains(r.id),
                      title: Text(
                        '${r.gender == RabbitGender.male ? '♂' : '♀'} ${r.name}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Bague ${r.tagNumber}',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      onChanged:
                          (v) => setState(() {
                            if (v == true) {
                              _rabbitIds.add(r.id);
                            } else {
                              _rabbitIds.remove(r.id);
                            }
                          }),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('record-notes'),
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (dosage, produit, observations…)',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                key: const ValueKey('record-error'),
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                key: const ValueKey('record-submit'),
                onPressed: _saving ? null : _submit,
                child:
                    _saving
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : Text(
                          isEdit
                              ? 'Enregistrer les modifications'
                              : 'Enregistrer le soin',
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
