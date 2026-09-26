import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/litter.dart';
import '../models/mating.dart';
import '../providers/rabbit_provider.dart';
import '../theme/colors.dart';

/// Formulaire d'enregistrement d'une mise bas. Avec [mating], la mise bas est rattachée à cet
/// accouplement (depuis sa carte) ; sinon on choisit parmi les accouplements en cours.
///
/// Concordance des dates : une mise bas ne peut être enregistrée que 21 jours au moins après la saillie.
Future<void> showLitterForm(
  BuildContext context,
  RabbitProvider provider, {
  Mating? mating,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => LitterFormSheet(provider: provider, mating: mating),
  );
}

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class LitterFormSheet extends StatefulWidget {
  final RabbitProvider provider;
  final Mating? mating;

  const LitterFormSheet({super.key, required this.provider, this.mating});

  @override
  State<LitterFormSheet> createState() => _LitterFormSheetState();
}

class _LitterFormSheetState extends State<LitterFormSheet> {
  late final List<Mating> _choices;
  String? _matingId;
  late DateTime _birthDate;
  final _alive = TextEditingController(text: '6');
  final _stillBorn = TextEditingController(text: '0');
  final _notes = TextEditingController();

  RabbitProvider get provider => widget.provider;

  Mating? get _mating => widget.mating ?? provider.getMatingById(_matingId);

  @override
  void initState() {
    super.initState();
    _choices = widget.mating != null ? [widget.mating!] : provider.matingsAwaitingKindling;
    // Par défaut : le premier accouplement dont la mise bas est déjà possible
    final firstReady = _choices.where((m) => m.canRegisterKindling).firstOrNull;
    _matingId = widget.mating?.id ?? (firstReady ?? _choices.firstOrNull)?.id;
    _birthDate = _dayOnly(DateTime.now());
    _clampBirthDate();
  }

  @override
  void dispose() {
    _alive.dispose();
    _stillBorn.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// La naissance ne peut pas précéder la saillie de 21 jours ni être dans le futur.
  void _clampBirthDate() {
    final m = _mating;
    if (m != null && _birthDate.isBefore(m.earliestKindlingDate)) {
      _birthDate = m.earliestKindlingDate;
    }
    final today = _dayOnly(DateTime.now());
    if (_birthDate.isAfter(today)) _birthDate = today;
  }

  Future<void> _pickDate() async {
    final m = _mating;
    final today = _dayOnly(DateTime.now());
    final first = m?.earliestKindlingDate ?? today.subtract(const Duration(days: 120));
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate.isBefore(first) ? first : _birthDate,
      firstDate: first,
      lastDate: today,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  void _submit() {
    final m = _mating;
    if (m == null || !m.canRegisterKindling) return;
    final notes = _notes.text.trim();
    provider.addLitter(
      Litter(
        id: 'lit-${DateTime.now().millisecondsSinceEpoch}',
        matingId: m.id,
        motherId: m.femaleId,
        fatherId: m.maleId,
        birthDate: _birthDate,
        bornAlive: int.tryParse(_alive.text) ?? 1,
        stillBorn: int.tryParse(_stillBorn.text) ?? 0,
        notes: notes.isEmpty ? null : notes,
      ),
    );
    final weaning = _birthDate.add(const Duration(days: Litter.defaultWeaningDays));
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Mise bas du ${DateFormat('dd/MM/yyyy').format(_birthDate)} enregistrée · '
          'sevrage prévu le ${DateFormat('dd/MM').format(weaning)}.',
        ),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = _mating;
    final ready = m != null && m.canRegisterKindling;
    final mother = provider.getRabbitById(m?.femaleId);
    final father = provider.getRabbitById(m?.maleId);
    final today = _dayOnly(DateTime.now());
    final daysAgo = today.difference(_birthDate).inDays;

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
              'Enregistrer une Mise Bas 🧺',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (_choices.isEmpty)
              _notice(
                "Aucun accouplement en attente de mise bas. Enregistrez d'abord un accouplement dans l'onglet « Accouplements ».",
              )
            else ...[
              if (widget.mating == null)
                DropdownButtonFormField<String>(
                  key: const ValueKey('litter-mating-dropdown'),
                  isExpanded: true,
                  value: _matingId,
                  decoration: const InputDecoration(
                    labelText: 'Accouplement concerné *',
                    prefixIcon: Icon(Icons.favorite, color: AppColors.primary),
                  ),
                  items: _choices.map((c) {
                    final f = provider.getRabbitById(c.femaleId);
                    final mm = provider.getRabbitById(c.maleId);
                    // Grisé tant que 21 jours ne se sont pas écoulés depuis la saillie
                    return DropdownMenuItem(
                      value: c.id,
                      enabled: c.canRegisterKindling,
                      child: Text(
                        '${f?.name ?? 'Femelle'} ♀ x ${mm?.name ?? 'Mâle'} ♂ • saillie du ${DateFormat('dd/MM/yyyy').format(c.matingDate)}'
                        '${c.canRegisterKindling ? '' : ' (dès le ${DateFormat('dd/MM').format(c.earliestKindlingDate)})'}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.canRegisterKindling ? null : AppColors.textMuted,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() {
                    _matingId = v;
                    _clampBirthDate();
                  }),
                ),
              if (m != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Mère : ${mother?.name ?? 'Inconnue'} (${mother?.tagNumber ?? '-'}) • Père : ${father?.name ?? 'Inconnu'} (${father?.tagNumber ?? '-'})\n'
                  'Saillie du ${DateFormat('dd/MM/yyyy').format(m.matingDate)} · mise bas prévue le ${DateFormat('dd/MM/yyyy').format(m.expectedKindlingDate)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
              if (m != null && !ready)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _notice(
                    'Trop tôt : la mise bas ne peut être enregistrée que ${Mating.minGestationDays} jours '
                    'après la saillie, soit à partir du ${DateFormat('dd/MM/yyyy').format(m.earliestKindlingDate)}.',
                    key: const ValueKey('litter-too-early'),
                  ),
                ),
            ],
            if (ready) ...[
              const SizedBox(height: 12),
              InkWell(
                key: const ValueKey('litter-birth-date'),
                borderRadius: BorderRadius.circular(12),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date de la mise bas *',
                    prefixIcon: const Icon(Icons.event_outlined, color: AppColors.primary, size: 20),
                    suffixText: daysAgo == 0
                        ? "Aujourd'hui"
                        : daysAgo == 1
                            ? 'Hier'
                            : 'Il y a $daysAgo j',
                  ),
                  child: Text(DateFormat('dd/MM/yyyy').format(_birthDate)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sevrage prévu le ${DateFormat('dd/MM/yyyy').format(_birthDate.add(const Duration(days: Litter.defaultWeaningDays)))}',
                key: const ValueKey('litter-form-weaning-hint'),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _alive,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Nés vivants *',
                        prefixIcon: Icon(Icons.favorite, color: AppColors.primary, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _stillBorn,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Mort-nés',
                        prefixIcon: Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(
                  labelText: 'Observations sur le nid',
                  hintText: 'Poils abondants, lapereaux vigoureux...',
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                key: const ValueKey('litter-submit'),
                onPressed: ready ? _submit : null,
                child: const Text('Enregistrer la Portée'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notice(String text, {Key? key}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.statusPregnantBg,
        border: Border.all(color: AppColors.statusPregnantText),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: AppColors.statusPregnantText),
      ),
    );
  }
}
