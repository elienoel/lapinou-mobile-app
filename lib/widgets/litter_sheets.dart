import '../utils/formatters.dart';
import 'app_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/litter.dart';
import '../models/rabbit.dart';
import '../providers/rabbit_provider.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import 'plan_limit.dart';

/// Feuille « Sevrer la portée » : date, nombre de lapereaux sevrés et, si on le souhaite,
/// une fiche lapin pour tout ou partie d'entre eux (les autres se nomment plus tard). Renvoie true quand le sevrage a été enregistré.
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

/// Fiches des lapereaux à nommer (nom, bague, sexe), partagées par le sevrage
/// et l'enregistrement différé des lapereaux sevrés.
mixin _KitRowsEditor<T extends StatefulWidget> on State<T> {
  final List<_KitRow> rows = [];
  // Index des lignes à corriger après une tentative d'envoi
  final Set<int> invalid = {};

  Litter get kitsLitter;

  Rabbit? get mother =>
      context.read<RabbitProvider>().getRabbitById(kitsLitter.motherId);

  /// [count] lignes ; les lignes déjà remplies sont conservées.
  void syncRows(int count) {
    final motherTag = mother?.tagNumber ?? '';
    while (rows.length < count) {
      // La numérotation continue après les fiches déjà créées pour éviter les bagues en double
      final serial = kitsLitter.registeredCount + rows.length + 1;
      rows.add(
        _KitRow('Petit $serial', motherTag.isEmpty ? '' : '$motherTag-$serial'),
      );
    }
    while (rows.length > count) {
      rows.removeLast().dispose();
    }
  }

  void disposeRows() {
    for (final r in rows) {
      r.dispose();
    }
  }

  /// Vérifie les fiches avant envoi ; renvoie un message si quelque chose manque.
  String? validateRows() {
    invalid.clear();
    final seen = <String>{};
    String? message;
    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      final tag = r.tag.text.trim().toUpperCase();
      if (r.name.text.trim().isEmpty) {
        invalid.add(i);
        message ??= 'Lapereau ${i + 1} : donnez-lui un nom.';
      } else if (tag.isEmpty) {
        invalid.add(i);
        message ??= 'Lapereau ${i + 1} : indiquez sa bague.';
      } else if (!seen.add(tag)) {
        invalid.add(i);
        message ??=
            'Lapereau ${i + 1} : la bague $tag est déjà utilisée dans cette liste.';
      } else if (r.gender == null) {
        invalid.add(i);
        message ??= 'Lapereau ${i + 1} : choisissez mâle ou femelle.';
      }
    }
    return message;
  }

  List<WeanedKit> get kits => [
    for (final r in rows)
      WeanedKit(
        name: r.name.text.trim(),
        tagNumber: r.tag.text.trim().toUpperCase(),
        gender: r.gender!,
        color: mother?.color,
      ),
  ];

  Widget buildKitRow(int i) {
    final r = rows[i];
    final bad = invalid.contains(i);
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
              ButtonSegment(value: RabbitGender.male, label: Text('Mâle')),
              ButtonSegment(value: RabbitGender.female, label: Text('Femelle')),
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

Widget _hint(String text, {Key? key}) => Padding(
  padding: const EdgeInsets.only(top: 2),
  child: Text(
    text,
    key: key,
    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
  ),
);

Widget _errorText(String error) => Padding(
  padding: const EdgeInsets.only(top: 8),
  child: Text(
    error,
    key: const ValueKey('wean-error'),
    style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
  ),
);

class WeanLitterSheet extends StatefulWidget {
  final Litter litter;

  const WeanLitterSheet({super.key, required this.litter});

  @override
  State<WeanLitterSheet> createState() => _WeanLitterSheetState();
}

class _WeanLitterSheetState extends State<WeanLitterSheet>
    with _KitRowsEditor<WeanLitterSheet> {
  late int _count;
  late DateTime _date;
  // Le sexe se voit souvent mal au sevrage : on nomme plus tard par défaut
  bool _nameNow = false;
  late int _named;
  bool _saving = false;
  String? _error;

  Litter get litter => widget.litter;

  @override
  Litter get kitsLitter => litter;

  @override
  void initState() {
    super.initState();
    _count = litter.kitsRemaining;
    _named = _count;
    _date = DateTime.now();
  }

  @override
  void dispose() {
    disposeRows();
    super.dispose();
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

  void _setNamed(int value) {
    _named = value.clamp(1, _count);
    syncRows(_nameNow ? _named : 0);
  }

  Future<void> _submit() async {
    if (_nameNow) {
      final problem = validateRows();
      if (problem != null) {
        setState(() => _error = problem);
        return;
      }
      if (!await guardRabbitQuota(context, rows.length) || !mounted) return;
    }
    setState(() {
      _saving = true;
      _error = null;
      invalid.clear();
    });

    final error = await context.read<RabbitProvider>().weanLitter(
      litter.id,
      count: _count,
      weanedAt: _date,
      kits: _nameNow ? kits : const [],
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
    final mother = this.mother;
    final inCage = mother != null && mother.cageId != null;
    final remaining = litter.kitsRemaining;
    final later = _nameNow ? _count - _named : _count;

    return SheetBody(
      children: [
        Text(
          'Sevrer la portée de ${mother?.name ?? 'la mère'}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '$remaining lapereau${remaining > 1 ? 'x' : ''} au nid · né${litter.bornAlive > 1 ? 's' : ''} le '
          '${formatDate(litter.birthDate)} (J${litter.ageDays})',
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
            child: Text(formatDate(_date)),
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
                // « tous nommés » suit le nombre sevré ; un choix partiel est conservé
                final allNamed = _named == _count;
                _count = v;
                _setNamed(allNamed || _named > v ? v : _named);
              }),
        ),
        if (_count < remaining)
          _hint(
            'Sevrage partiel : ${remaining - _count} resteront au nid avec leur mère.',
          ),
        const SizedBox(height: 8),
        SwitchListTile(
          key: const ValueKey('wean-create-records'),
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.primary,
          title: const Text(
            'Nommer des lapereaux maintenant',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            inCage
                ? 'Fiches rattachées à la portée, dans la cage de la mère (${mother.cageNumber}).'
                : 'Fiches rattachées à la portée, à la mère et au père.',
            style: const TextStyle(fontSize: 12),
          ),
          value: _nameNow,
          onChanged:
              _saving
                  ? null
                  : (v) => setState(() {
                    _nameNow = v;
                    _setNamed(_count);
                  }),
        ),
        if (_nameNow && _count > 1)
          _Stepper(
            label: 'À nommer maintenant',
            value: _named,
            min: 1,
            max: _count,
            valueKey: const ValueKey('wean-named-count'),
            onChanged: (v) => setState(() => _setNamed(v)),
          ),
        if (later > 0)
          _hint(
            '$later lapereau${later > 1 ? 'x' : ''} à nommer plus tard : '
            '${later > 1 ? 'ils restent comptés' : 'il reste compté'} dans le cheptel.',
            key: const ValueKey('wean-later-hint'),
          ),
        if (_nameNow) ...[for (int i = 0; i < rows.length; i++) buildKitRow(i)],
        if (_error != null) _errorText(_error!),
        const SizedBox(height: 14),
        SubmitButton(
          key: const ValueKey('wean-submit'),
          label:
              _nameNow
                  ? 'Sevrer $_count et créer ${rows.length} fiche${rows.length > 1 ? 's' : ''}'
                  : 'Sevrer $_count lapereau${_count > 1 ? 'x' : ''}',
          saving: _saving,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// Feuille « Nommer les lapereaux » : crée les fiches de lapereaux déjà sevrés,
/// à tout moment (même accouplement clôturé). Renvoie true une fois enregistré.
Future<bool?> showRegisterKitsSheet(BuildContext context, Litter litter) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => RegisterKitsSheet(litter: litter),
  );
}

class RegisterKitsSheet extends StatefulWidget {
  final Litter litter;

  const RegisterKitsSheet({super.key, required this.litter});

  @override
  State<RegisterKitsSheet> createState() => _RegisterKitsSheetState();
}

class _RegisterKitsSheetState extends State<RegisterKitsSheet>
    with _KitRowsEditor<RegisterKitsSheet> {
  late int _count;
  bool _withMother = false;
  bool _saving = false;
  String? _error;

  @override
  Litter get kitsLitter => widget.litter;

  @override
  void initState() {
    super.initState();
    _count = widget.litter.kitsUnregistered;
    syncRows(_count);
  }

  @override
  void dispose() {
    disposeRows();
    super.dispose();
  }

  Future<void> _submit() async {
    final problem = validateRows();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    if (!await guardRabbitQuota(context, rows.length) || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final m = mother;
    final error = await context.read<RabbitProvider>().registerKits(
      widget.litter.id,
      kits: kits,
      cageId: _withMother ? m?.cageId : null,
      compartment: _withMother ? m?.compartmentNumber : null,
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
    final litter = widget.litter;
    final available = litter.kitsUnregistered;
    final m = mother;
    final motherPlaced = m?.cageId != null && m?.compartmentNumber != null;
    return SheetBody(
      children: [
        const Text(
          'Nommer les lapereaux',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '$available sevré${available > 1 ? 's' : ''} sans fiche · portée de '
          '${m?.name ?? 'la mère'} née le ${formatDate(litter.birthDate)}',
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        if (available > 1)
          _Stepper(
            label: 'Lapereaux à enregistrer',
            value: _count,
            min: 1,
            max: available,
            valueKey: const ValueKey('register-count'),
            onChanged:
                (v) => setState(() {
                  _count = v;
                  syncRows(v);
                }),
          ),
        if (_count < available)
          _hint(
            '${available - _count} resteront à nommer, toujours comptés dans le cheptel.',
          ),
        if (motherPlaced)
          SwitchListTile(
            key: const ValueKey('register-with-mother'),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
            title: const Text(
              'Placer dans la loge de la mère',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              _withMother
                  ? 'Cage ${m!.cageNumber}, loge ${m.compartmentNumber}.'
                  : 'Sinon, sans cage : vous pourrez les placer depuis leur fiche.',
              style: const TextStyle(fontSize: 12),
            ),
            value: _withMother,
            onChanged: _saving ? null : (v) => setState(() => _withMother = v),
          )
        else
          _hint('Sans cage pour l’instant : placez-les depuis leur fiche.'),
        for (int i = 0; i < rows.length; i++) buildKitRow(i),
        if (_error != null) _errorText(_error!),
        const SizedBox(height: 14),
        SubmitButton(
          key: const ValueKey('register-submit'),
          label: 'Créer ${rows.length} fiche${rows.length > 1 ? 's' : ''}',
          saving: _saving,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// Feuille « Vendus ou morts » : retire du cheptel des lapereaux sevrés sans fiche.
Future<bool?> showReleaseKitsSheet(BuildContext context, Litter litter) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => ReleaseKitsSheet(litter: litter),
  );
}

class ReleaseKitsSheet extends StatefulWidget {
  final Litter litter;

  const ReleaseKitsSheet({super.key, required this.litter});

  @override
  State<ReleaseKitsSheet> createState() => _ReleaseKitsSheetState();
}

class _ReleaseKitsSheetState extends State<ReleaseKitsSheet> {
  int _count = 1;
  bool _sold = true;
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await context.read<RabbitProvider>().releaseKits(
      widget.litter.id,
      count: _count,
      sold: _sold,
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
    final available = widget.litter.kitsUnregistered;
    final left = available - _count;
    return SheetBody(
      children: [
        const Text(
          'Lapereaux vendus ou morts',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '$available sevré${available > 1 ? 's' : ''} sans fiche dans cette portée',
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        SegmentedButton<bool>(
          key: const ValueKey('release-reason'),
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: AppColors.primary,
            selectedForegroundColor: Colors.white,
          ),
          segments: const [
            ButtonSegment(value: true, label: Text('Vendus')),
            ButtonSegment(value: false, label: Text('Morts')),
          ],
          selected: {_sold},
          onSelectionChanged: (v) => setState(() => _sold = v.first),
        ),
        const SizedBox(height: 10),
        _Stepper(
          label: 'Nombre de lapereaux',
          value: _count,
          min: 1,
          max: available,
          valueKey: const ValueKey('release-count'),
          onChanged: (v) => setState(() => _count = v),
        ),
        _hint(
          left > 0
              ? 'Il en restera $left dans le cheptel, à nommer.'
              : 'Plus aucun lapereau sans fiche dans cette portée.',
        ),
        if (_error != null) _errorText(_error!),
        const SizedBox(height: 14),
        SubmitButton(
          key: const ValueKey('release-submit'),
          label: 'Retirer $_count lapereau${_count > 1 ? 'x' : ''}',
          saving: _saving,
          onPressed: _submit,
        ),
      ],
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
    return SheetBody(
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
            child: Text(formatDate(_weaningDate)),
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
    );
  }
}
