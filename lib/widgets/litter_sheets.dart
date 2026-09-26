import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/litter.dart';
import '../models/rabbit.dart';
import '../providers/rabbit_provider.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';

/// Feuille « Sevrer la portée » : date, nombre de lapereaux sevrés et, si on le souhaite,
/// une fiche lapin par lapereau. Renvoie true quand le sevrage a été enregistré.
Future<bool?> showWeanLitterSheet(BuildContext context, Litter litter) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => WeanLitterSheet(litter: litter),
  );
}

/// Feuille « Modifier la portée » : effectifs, morts au nid, date de sevrage prévue, notes.
Future<bool?> showEditLitterSheet(BuildContext context, Litter litter) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => EditLitterSheet(litter: litter),
  );
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final Key? valueKey;

  const _Stepper({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 99,
    this.valueKey,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
        ),
        IconButton.filled(
          visualDensity: VisualDensity.compact,
          tooltip: 'Moins',
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 38,
          child: Text(
            '$value',
            key: valueKey,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
        IconButton.filled(
          visualDensity: VisualDensity.compact,
          tooltip: 'Plus',
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _KitRow {
  final TextEditingController name;
  final TextEditingController tag;
  RabbitGender? gender;

  _KitRow(String name, String tag)
    : name = TextEditingController(text: name),
      tag = TextEditingController(text: tag);

  void dispose() {
    name.dispose();
    tag.dispose();
  }
}

class WeanLitterSheet extends StatefulWidget {
  final Litter litter;

  const WeanLitterSheet({super.key, required this.litter});

  @override
  State<WeanLitterSheet> createState() => _WeanLitterSheetState();
}

class _WeanLitterSheetState extends State<WeanLitterSheet> {
  late int _count;
  late DateTime _date;
  bool _createRecords = true;
  bool _saving = false;
  String? _error;
  final List<_KitRow> _rows = [];
  // Index des lignes à corriger après une tentative d'envoi
  final Set<int> _invalid = {};

  Litter get litter => widget.litter;

  @override
  void initState() {
    super.initState();
    _count = litter.kitsRemaining;
    _date = DateTime.now();
    _syncRows();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Rabbit? get _mother =>
      context.read<RabbitProvider>().getRabbitById(litter.motherId);

  /// Une ligne par lapereau sevré ; les lignes déjà remplies sont conservées.
  void _syncRows() {
    final motherTag = _mother?.tagNumber ?? '';
    while (_rows.length < _count) {
      final n = _rows.length + 1;
      // La numérotation continue après les sevrages précédents pour éviter les bagues en double
      final serial = litter.weaned + n;
      _rows.add(
        _KitRow('Petit $serial', motherTag.isEmpty ? '' : '$motherTag-$serial'),
      );
    }
    while (_rows.length > _count) {
      _rows.removeLast().dispose();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: litter.birthDate,
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  /// Vérifie les fiches avant envoi ; renvoie un message si quelque chose manque.
  String? _validateRows() {
    _invalid.clear();
    final seen = <String>{};
    String? message;
    for (int i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final tag = r.tag.text.trim().toUpperCase();
      if (r.name.text.trim().isEmpty) {
        _invalid.add(i);
        message ??= 'Lapereau ${i + 1} : donnez-lui un nom.';
      } else if (tag.isEmpty) {
        _invalid.add(i);
        message ??= 'Lapereau ${i + 1} : indiquez sa bague.';
      } else if (!seen.add(tag)) {
        _invalid.add(i);
        message ??=
            'Lapereau ${i + 1} : la bague $tag est déjà utilisée dans cette liste.';
      } else if (r.gender == null) {
        _invalid.add(i);
        message ??= 'Lapereau ${i + 1} : choisissez ♂ ou ♀.';
      }
    }
    return message;
  }

  Future<void> _submit() async {
    if (_createRecords) {
      final problem = _validateRows();
      if (problem != null) {
        setState(() => _error = problem);
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
      _invalid.clear();
    });

    final provider = context.read<RabbitProvider>();
    final mother = _mother;
    final error = await provider.weanLitter(
      litter.id,
      count: _count,
      weanedAt: _date,
      kits:
          _createRecords
              ? [
                for (final r in _rows)
                  WeanedKit(
                    name: r.name.text.trim(),
                    tagNumber: r.tag.text.trim().toUpperCase(),
                    gender: r.gender!,
                    color: mother?.color,
                  ),
              ]
              : const [],
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
    final mother = _mother;
    final inCage = mother != null && mother.cageId != null;
    final remaining = litter.kitsRemaining;

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
              'Sevrer la portée de ${mother?.name ?? 'la mère'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '$remaining lapereau${remaining > 1 ? 'x' : ''} au nid · né${litter.bornAlive > 1 ? 's' : ''} le '
              '${DateFormat('dd/MM/yyyy').format(litter.birthDate)} (J${litter.ageDays})',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              key: const ValueKey('wean-date'),
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date du sevrage',
                  prefixIcon: Icon(Icons.event_outlined, size: 20),
                ),
                child: Text(DateFormat('dd/MM/yyyy').format(_date)),
              ),
            ),
            const SizedBox(height: 12),
            _Stepper(
              label: 'Lapereaux sevrés',
              value: _count,
              min: 1,
              max: remaining,
              valueKey: const ValueKey('wean-count'),
              onChanged:
                  (v) => setState(() {
                    _count = v;
                    _syncRows();
                  }),
            ),
            if (_count < remaining)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Sevrage partiel : ${remaining - _count} resteront au nid avec leur mère.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const ValueKey('wean-create-records'),
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.primary,
              title: const Text(
                'Créer les fiches lapins',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                inCage
                    ? 'Rattachées à la mère et au père, dans sa cage (${mother.cageNumber}).'
                    : 'Rattachées à la mère et au père.',
                style: const TextStyle(fontSize: 12),
              ),
              value: _createRecords,
              onChanged:
                  _saving ? null : (v) => setState(() => _createRecords = v),
            ),
            if (_createRecords) ...[
              for (int i = 0; i < _rows.length; i++) _buildKitRow(i),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                key: const ValueKey('wean-error'),
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                key: const ValueKey('wean-submit'),
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
                          _createRecords
                              ? 'Sevrer $_count et créer les fiches'
                              : 'Sevrer $_count lapereau${_count > 1 ? 'x' : ''}',
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKitRow(int i) {
    final r = _rows[i];
    final bad = _invalid.contains(i);
    return Container(
      key: ValueKey('kit-row-$i'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrey,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: bad ? Colors.red.shade400 : AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lapereau ${i + 1}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey('kit-name-$i'),
                  controller: r.name,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: ValueKey('kit-tag-$i'),
                  controller: r.tag,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Bague',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<RabbitGender>(
            key: ValueKey('kit-gender-$i'),
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              selectedBackgroundColor: AppColors.primary,
              selectedForegroundColor: Colors.white,
            ),
            segments: const [
              ButtonSegment(value: RabbitGender.male, label: Text('♂ Mâle')),
              ButtonSegment(
                value: RabbitGender.female,
                label: Text('♀ Femelle'),
              ),
            ],
            selected: {if (r.gender != null) r.gender!},
            onSelectionChanged:
                (v) => setState(() => r.gender = v.isEmpty ? null : v.first),
          ),
        ],
      ),
    );
  }
}

class EditLitterSheet extends StatefulWidget {
  final Litter litter;

  const EditLitterSheet({super.key, required this.litter});

  @override
  State<EditLitterSheet> createState() => _EditLitterSheetState();
}

class _EditLitterSheetState extends State<EditLitterSheet> {
  late int _alive;
  late int _stillBorn;
  late int _died;
  late DateTime _weaningDate;
  late final TextEditingController _notes;
  bool _saving = false;
  String? _error;

  Litter get litter => widget.litter;

  @override
  void initState() {
    super.initState();
    _alive = litter.bornAlive;
    _stillBorn = litter.stillBorn;
    _died = litter.diedCount;
    _weaningDate = litter.calculatedWeaningDate;
    _notes = TextEditingController(text: litter.notes ?? '');
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  /// Sevrés et morts déjà enregistrés : le nombre de nés vivants ne peut pas descendre en dessous.
  int get _minAlive => litter.weaned + _died;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _weaningDate,
      firstDate: litter.birthDate,
      lastDate: litter.birthDate.add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _weaningDate = picked);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final notes = _notes.text.trim();
    final error = await context.read<RabbitProvider>().updateLitter(
      litter.copyWith(
        bornAlive: _alive,
        stillBorn: _stillBorn,
        diedCount: _died,
        weaningDate: _weaningDate,
        notes: notes,
        clearNotes: notes.isEmpty,
      ),
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
    final remaining = (_alive - litter.weaned - _died).clamp(0, 999);
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
            const Text(
              'Modifier la portée',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            _Stepper(
              label: 'Nés vivants',
              value: _alive,
              min: _minAlive,
              valueKey: const ValueKey('edit-alive'),
              onChanged: (v) => setState(() => _alive = v),
            ),
            _Stepper(
              label: 'Mort-nés',
              value: _stillBorn,
              valueKey: const ValueKey('edit-stillborn'),
              onChanged: (v) => setState(() => _stillBorn = v),
            ),
            _Stepper(
              label: 'Morts au nid',
              value: _died,
              max: (_alive - litter.weaned).clamp(0, 99),
              valueKey: const ValueKey('edit-died'),
              onChanged: (v) => setState(() => _died = v),
            ),
            const SizedBox(height: 6),
            Text(
              'Restent au nid : $remaining · déjà sevrés : ${litter.weaned}',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              key: const ValueKey('edit-weaning-date'),
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date de sevrage prévue',
                  prefixIcon: Icon(Icons.event_outlined, size: 20),
                ),
                child: Text(DateFormat('dd/MM/yyyy').format(_weaningDate)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('edit-notes'),
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Observations'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                key: const ValueKey('edit-save'),
                onPressed: _saving ? null : _save,
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
                        : const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
