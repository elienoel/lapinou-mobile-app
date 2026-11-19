import '../utils/formatters.dart';
import '../widgets/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/litter.dart';
import '../models/mating.dart';
import '../models/rabbit.dart';
import '../providers/auth_provider.dart';
import '../providers/rabbit_provider.dart';
import '../theme/colors.dart';
import '../widgets/pair_avatars.dart';
import 'mating_detail_screen.dart';

enum _MatingFilter { active, finished, all }

/// Accouplements & mises bas : une seule liste. Chaque accouplement est suivi
/// étape par étape (palpation, boîte à nid, mise bas, sevrage, clôture) dans
/// son détail ; la carte n'en montre que l'essentiel.
class MatingsScreen extends StatefulWidget {
  const MatingsScreen({super.key});

  @override
  State<MatingsScreen> createState() => _MatingsScreenState();
}

/// Élément de la liste : un accouplement (avec sa portée éventuelle), ou une
/// ancienne portée enregistrée sans accouplement.
class _Entry {
  _Entry.mating(Mating this.mating, this.litter);
  _Entry.litter(Litter this.litter) : mating = null;

  final Mating? mating;
  final Litter? litter;

  /// Suivi en cours (ni réussi, ni échoué ; portée orpheline pas encore sevrée)
  bool get ongoing => mating?.isOngoing ?? !litter!.isWeaned;
}

class _MatingsScreenState extends State<MatingsScreen> {
  _MatingFilter _filter = _MatingFilter.active;

  List<_Entry> _entries(RabbitProvider provider) {
    final matingIds = provider.matings.map((m) => m.id).toSet();
    return [
      for (final m in provider.matings)
        _Entry.mating(m, provider.litterOfMating(m.id)),
      for (final l in provider.litters)
        if (l.matingId == null || !matingIds.contains(l.matingId))
          _Entry.litter(l),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RabbitProvider>(
      builder: (context, provider, child) {
        final all = _entries(provider);
        final active = all.where((e) => e.ongoing).toList();
        final finished = all.where((e) => !e.ongoing).toList();
        final shown = switch (_filter) {
          _MatingFilter.active => active,
          _MatingFilter.finished => finished,
          _MatingFilter.all => all,
        };

        return Scaffold(
          appBar: AppBar(
            leading:
                Navigator.canPop(context)
                    ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      onPressed: () => Navigator.pop(context),
                    )
                    : null,
            title: const Text('Accouplements & Mises bas'),
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                final token = context.read<AuthProvider>().token;
                await Future.wait([
                  provider.fetchMatings(token: token),
                  provider.fetchLitters(token: token),
                  provider.fetchRabbits(token: token),
                ]);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 96),
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _filterChip(
                          _MatingFilter.active,
                          'En cours (${active.length})',
                        ),
                        const SizedBox(width: 8),
                        _filterChip(
                          _MatingFilter.finished,
                          'Terminés (${finished.length})',
                        ),
                        const SizedBox(width: 8),
                        _filterChip(_MatingFilter.all, 'Tous (${all.length})'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (shown.isEmpty)
                    _buildEmpty()
                  else
                    for (final e in shown) _buildCard(context, provider, e),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_matings',
            onPressed: () => showMatingForm(context, provider),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.favorite),
            label: const Text('Nouvel accouplement'),
          ),
        );
      },
    );
  }

  Widget _filterChip(_MatingFilter value, String label) {
    final selected = _filter == value;
    return InkWell(
      key: ValueKey('mating-filter-${value.name}'),
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final text = switch (_filter) {
      _MatingFilter.active => 'Aucun accouplement en cours.',
      _MatingFilter.finished => 'Aucun accouplement terminé.',
      _MatingFilter.all => 'Aucun accouplement enregistré.',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }

  /// Carte sommaire : les deux lapins, la date, et où en est le suivi.
  Widget _buildCard(BuildContext context, RabbitProvider provider, _Entry e) {
    final m = e.mating;
    final litter = e.litter;
    final female = provider.getRabbitById(m?.femaleId ?? litter!.motherId);
    final male = provider.getRabbitById(m?.maleId ?? litter!.fatherId);
    final (value, caption, color) = matingStage(m, litter);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: ValueKey(m != null ? 'mating-${m.id}' : 'litter-${litter!.id}'),
          borderRadius: BorderRadius.circular(18),
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => MatingDetailScreen(
                        matingId: m?.id,
                        litterId: m == null ? litter!.id : null,
                      ),
                ),
              ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                PairAvatars(female: female, male: male),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: female?.name ?? 'Femelle'),
                            const TextSpan(
                              text: ' ♀  ×  ',
                              style: TextStyle(color: AppColors.femalePink),
                            ),
                            TextSpan(text: male?.name ?? 'Mâle'),
                            const TextSpan(
                              text: ' ♂',
                              style: TextStyle(color: AppColors.maleBlue),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        m != null
                            ? 'Saillie le ${formatDate(m.matingDate)}'
                            : 'Mise bas le ${formatDate(litter!.birthDate)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StageBadge(value: value, caption: caption, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Résumé de l'avancement pour la carte : (valeur, légende, couleur).
/// Pendant la gestation : le compte à rebours avant la mise bas (J-12).
(String, String, Color) matingStage(Mating? m, Litter? litter) {
  if (m?.status == MatingStatus.failed) {
    return ('Échec', 'non réussi', AppColors.statusAlertText);
  }
  if (m?.status == MatingStatus.completed) {
    return ('Réussi', 'terminé', AppColors.statusActiveText);
  }
  if (m != null && m.isActive) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = m.expectedKindlingDate;
    final d = DateTime(due.year, due.month, due.day).difference(today).inDays;
    if (d > 0) return ('J-$d', 'mise bas', AppColors.secondary);
    if (d == 0) return ('Jour J', 'mise bas', AppColors.statusPregnantText);
    return ('J+${-d}', 'mise bas attendue', AppColors.statusPregnantText);
  }
  if (litter != null) {
    final kits = litter.kitsRemaining;
    switch (litter.status) {
      case LitterStatus.nursing:
        return ('$kits', kits > 1 ? 'au nid' : 'au nid', AppColors.secondary);
      case LitterStatus.weaningDue:
        return ('Sevrage', 'à faire', AppColors.statusAlertText);
      case LitterStatus.weaned:
        return m == null
            ? ('Sevrée', 'terminé', AppColors.statusActiveText)
            : ('À clôturer', 'sevrage fait', AppColors.statusActiveText);
    }
  }
  return ('Mise bas', 'enregistrée', AppColors.secondary);
}

class _StageBadge extends StatelessWidget {
  const _StageBadge({
    required this.value,
    required this.caption,
    required this.color,
  });

  final String value;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 64),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.1,
            ),
          ),
          Text(
            caption,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withAlpha(200),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Formulaire, échec, suppression : partagés avec le détail ----

/// Formulaire d'accouplement : création, ou modification si [existing] est fourni.
void showMatingForm(
  BuildContext context,
  RabbitProvider provider, {
  Mating? existing,
}) {
  final isEdit = existing != null;
  String? selectedMaleId =
      isEdit
          ? existing.maleId
          : (provider.males.isNotEmpty ? provider.males.first.id : null);
  String? selectedFemaleId =
      isEdit
          ? existing.femaleId
          : (provider.females.isNotEmpty ? provider.females.first.id : null);
  // Un lapin supprimé depuis ne figure plus dans la liste : on force le choix
  if (!provider.males.any((r) => r.id == selectedMaleId)) {
    selectedMaleId = null;
  }
  if (!provider.females.any((r) => r.id == selectedFemaleId)) {
    selectedFemaleId = null;
  }
  DateTime matingDate = existing?.matingDate ?? DateTime.now();
  final notesController = TextEditingController(text: existing?.notes ?? '');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final currentSelectedDay = DateTime(
            matingDate.year,
            matingDate.month,
            matingDate.day,
          );
          final daysAgo = today.difference(currentSelectedDay).inDays;
          final isToday = daysAgo == 0;

          final palpationDate = matingDate.add(const Duration(days: 12));
          final nestBoxDate = matingDate.add(const Duration(days: 28));
          final expectedKindlingDate = matingDate.add(const Duration(days: 31));

          final formattedDate = DateFormat(
            'EEEE d MMMM yyyy',
            'fr_FR',
          ).format(matingDate);
          final capitalizedDate =
              formattedDate.isNotEmpty
                  ? '${formattedDate[0].toUpperCase()}${formattedDate.substring(1)}'
                  : formattedDate;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEdit
                            ? "Modifier l'accouplement"
                            : 'Enregistrer un Accouplement',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Male selector
                  _ReproducerField(
                    key: const ValueKey('mating-male-field'),
                    label: 'Mâle reproducteur ♂',
                    icon: Icons.male,
                    accentColor: AppColors.maleBlue,
                    selected: provider.getRabbitById(selectedMaleId),
                    onTap: () async {
                      final picked = await _pickReproducer(
                        ctx,
                        title: 'Choisir le mâle reproducteur',
                        rabbits: provider.males,
                        accentColor: AppColors.maleBlue,
                      );
                      if (picked != null) {
                        setModalState(() => selectedMaleId = picked.id);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Female selector
                  _ReproducerField(
                    key: const ValueKey('mating-female-field'),
                    label: 'Femelle reproductrice ♀',
                    icon: Icons.female,
                    accentColor: AppColors.femalePink,
                    selected: provider.getRabbitById(selectedFemaleId),
                    onTap: () async {
                      final picked = await _pickReproducer(
                        ctx,
                        title: 'Choisir la femelle reproductrice',
                        rabbits: provider.females,
                        accentColor: AppColors.femalePink,
                      );
                      if (picked != null) {
                        setModalState(() => selectedFemaleId = picked.id);
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Mating Date Selector
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: matingDate,
                        firstDate:
                            matingDate.isBefore(
                                  now.subtract(const Duration(days: 90)),
                                )
                                ? matingDate
                                : now.subtract(const Duration(days: 90)),
                        lastDate: now,
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
                        setModalState(() {
                          matingDate = picked;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.scaffoldBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.cardBorder,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.calendar_month_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Date de la saillie / accouplement',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  capitalizedDate,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isToday ? "Aujourd'hui" : "Il y a $daysAgo j",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color:
                                    isToday
                                        ? AppColors.primary
                                        : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Dynamic Milestones Preview
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primarySoftBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 15,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Échéances calculées • Gestation J${daysAgo + 1}/31',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _milestoneItem(
                              title: 'Palpation',
                              dayBadge: 'J+12',
                              date: DateFormat(
                                'dd/MM',
                                'fr_FR',
                              ).format(palpationDate),
                              isPassed: daysAgo >= 12,
                            ),
                            _milestoneItem(
                              title: 'Boîte à nid',
                              dayBadge: 'J+28',
                              date: DateFormat(
                                'dd/MM',
                                'fr_FR',
                              ).format(nestBoxDate),
                              isPassed: daysAgo >= 28,
                            ),
                            _milestoneItem(
                              title: 'Mise bas',
                              dayBadge: 'J+31',
                              date: DateFormat(
                                'dd/MM',
                                'fr_FR',
                              ).format(expectedKindlingDate),
                              isPassed: daysAgo >= 31,
                              isHighlight: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Observations
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Observations (optionnel)',
                      hintText: 'Nombre de sauts observés, comportement...',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (selectedMaleId != null &&
                            selectedFemaleId != null) {
                          final auth = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          );
                          final notes = notesController.text.trim();
                          final messenger = ScaffoldMessenger.of(context);
                          final sire = provider.getRabbitById(selectedMaleId);
                          final dam = provider.getRabbitById(selectedFemaleId);
                          if (sire?.gender != RabbitGender.male ||
                              dam?.gender != RabbitGender.female) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Le mâle doit être un mâle et la femelle une femelle.',
                                ),
                                backgroundColor: Colors.red.shade700,
                              ),
                            );
                            return;
                          }
                          if (isEdit) {
                            provider
                                .updateMating(
                                  existing.copyWith(
                                    maleId: selectedMaleId,
                                    femaleId: selectedFemaleId,
                                    matingDate: matingDate,
                                    notes: notes,
                                    clearNotes: notes.isEmpty,
                                  ),
                                  token: auth.token,
                                )
                                .then(
                                  (ok) => messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Accouplement modifié, échéances recalculées.'
                                            : 'Échec de la modification, réessayez.',
                                      ),
                                      backgroundColor:
                                          ok
                                              ? AppColors.primary
                                              : Colors.redAccent,
                                    ),
                                  ),
                                );
                            Navigator.pop(ctx);
                            return;
                          }
                          final newMating = Mating(
                            id: 'mat-${DateTime.now().millisecondsSinceEpoch}',
                            maleId: selectedMaleId!,
                            femaleId: selectedFemaleId!,
                            matingDate: matingDate,
                            status: MatingStatus.pending,
                            notes: notes.isEmpty ? null : notes,
                          );
                          provider.addMating(newMating, token: auth.token);
                          Navigator.pop(ctx);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                isToday
                                    ? 'Accouplement enregistré avec succès !'
                                    : 'Accouplement du ${formatDate(matingDate)} enregistré (J${daysAgo + 1} de gestation) !',
                              ),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        }
                      },
                      child: Text(
                        isEdit
                            ? 'Enregistrer les modifications'
                            : 'Valider et Calculer la mise bas',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _milestoneItem({
  required String title,
  required String dayBadge,
  required String date,
  bool isPassed = false,
  bool isHighlight = false,
}) {
  return Column(
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isHighlight ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 2),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color:
              isPassed
                  ? Colors.white
                  : (isHighlight ? AppColors.primary : Colors.white),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          isPassed ? 'Fait' : dayBadge,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color:
                isPassed
                    ? Colors.grey.shade700
                    : (isHighlight ? Colors.white : AppColors.primary),
          ),
        ),
      ),
      const SizedBox(height: 2),
      Text(
        date,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color:
              isPassed
                  ? Colors.grey.shade600
                  : (isHighlight ? AppColors.primary : AppColors.textPrimary),
        ),
      ),
    ],
  );
}

/// Déclare l'accouplement non réussi (échec), avec un motif facultatif.
/// Renvoie true si l'échec a été enregistré.
Future<bool> confirmMatingFailure(
  BuildContext context,
  RabbitProvider provider,
  Mating m, {
  String initialReason = '',
}) async {
  final female = provider.getRabbitById(m.femaleId);
  final male = provider.getRabbitById(m.maleId);

  // null = retour ; sinon le motif saisi (éventuellement vide)
  final reason = await showDialog<String>(
    context: context,
    builder:
        (ctx) => _CancelMatingDialog(
          initialReason: initialReason,
          summary:
              "L'accouplement ${female?.name ?? 'Femelle'} × ${male?.name ?? 'Mâle'} sera marqué comme non réussi "
              'et la femelle redeviendra disponible.',
        ),
  );
  if (reason == null || !context.mounted) return false;

  final error = await provider.cancelMating(m, reason: reason);
  if (!context.mounted) return false;
  showAppSnack(
    context,
    error ?? 'Accouplement marqué comme non réussi',
    error: error != null,
  );
  return error == null;
}

/// Supprime un accouplement après confirmation. Renvoie true s'il a été supprimé.
Future<bool> confirmDeleteMating(
  BuildContext context,
  RabbitProvider provider,
  Mating m,
) async {
  final female = provider.getRabbitById(m.femaleId)?.name ?? 'la femelle';
  final male = provider.getRabbitById(m.maleId)?.name ?? 'le mâle';
  final ok = await confirmAction(
    context,
    title: 'Supprimer cet accouplement ?',
    message:
        "L'accouplement $female × $male sera retiré de la liste. Cette action est définitive.",
    destructive: true,
  );
  if (ok != true || !context.mounted) return false;
  final error = await provider.deleteMating(m.id);
  if (!context.mounted) return false;
  showAppSnack(context, error ?? 'Accouplement supprimé', error: error != null);
  return error == null;
}

/// Enregistre la pose de la boîte à nid en demandant sa date.
Future<void> confirmMatingNestBox(
  BuildContext context,
  RabbitProvider provider,
  Mating m,
) async {
  final today = DateTime.now();
  final dayOnly = DateTime(today.year, today.month, today.day);
  final picked = await showDatePicker(
    context: context,
    helpText: 'Date de pose de la boîte à nid',
    initialDate: dayOnly,
    firstDate: DateTime(
      m.matingDate.year,
      m.matingDate.month,
      m.matingDate.day,
    ),
    lastDate: dayOnly,
  );
  if (picked == null || !context.mounted) return;
  final error = await provider.confirmNestBox(m, doneAt: picked);
  if (!context.mounted) return;
  showAppSnack(
    context,
    error ?? 'Pose de la boîte à nid enregistrée',
    error: error != null,
  );
}

/// Clôture l'accouplement comme réussi (portée sevrée).
Future<void> confirmMatingSuccess(
  BuildContext context,
  RabbitProvider provider,
  Mating m,
) async {
  final ok = await confirmAction(
    context,
    title: 'Accouplement réussi ?',
    message:
        "La portée est sevrée : l'accouplement sera marqué comme terminé et réussi.",
    confirmLabel: 'Marquer comme réussi',
  );
  if (ok != true || !context.mounted) return;
  final error = await provider.completeMating(m);
  if (!context.mounted) return;
  showAppSnack(
    context,
    error ?? 'Accouplement terminé : réussi',
    error: error != null,
  );
}

/// Confirme la palpation d'un accouplement (gestation confirmée) en demandant
/// la date à laquelle elle a été faite. Fonction partagée entre l'écran
/// Accouplements et le rappel de la page d'accueil.
Future<void> confirmMatingPalpation(
  BuildContext context,
  RabbitProvider provider,
  Mating m,
) async {
  final female = provider.getRabbitById(m.femaleId);
  final today = DateTime.now();
  final dayOnly = DateTime(today.year, today.month, today.day);
  var date = dayOnly;

  final ok = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => StatefulBuilder(
          builder:
              (ctx, setDialogState) => AlertDialog(
                title: const Text('Palpation effectuée'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confirmez que la palpation de ${female?.name ?? 'la femelle'} a été faite et que la gestation est confirmée.',
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      key: const ValueKey('palpation-date'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(
                            m.matingDate.year,
                            m.matingDate.month,
                            m.matingDate.day,
                          ),
                          lastDate: dayOnly,
                        );
                        if (picked != null) {
                          setDialogState(() => date = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date de la palpation',
                          prefixIcon: Icon(Icons.event_outlined, size: 20),
                        ),
                        child: Text(formatDate(date)),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    key: const ValueKey('palpation-confirm'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Confirmer'),
                  ),
                ],
              ),
        ),
  );
  if (ok != true || !context.mounted) return;

  final error = await provider.confirmPalpation(m, doneAt: date);
  if (!context.mounted) return;
  showAppSnack(context, error ?? 'Palpation enregistrée : gestation confirmée');
}

/// Confirmation d'échec d'un accouplement, avec un motif facultatif.
/// Renvoie le motif (peut être vide) si on confirme, null si on revient en arrière.
class _CancelMatingDialog extends StatefulWidget {
  final String summary;

  const _CancelMatingDialog({required this.summary, this.initialReason = ''});

  final String initialReason;

  @override
  State<_CancelMatingDialog> createState() => _CancelMatingDialogState();
}

class _CancelMatingDialogState extends State<_CancelMatingDialog> {
  late final _reason = TextEditingController(text: widget.initialReason);

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Déclarer l'échec ?"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.summary),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('cancel-reason'),
            controller: _reason,
            decoration: const InputDecoration(
              labelText: 'Motif (optionnel)',
              hintText: 'Non gestante à la palpation…',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Retour'),
        ),
        FilledButton(
          key: const ValueKey('cancel-confirm'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () => Navigator.pop(context, _reason.text),
          child: const Text("Déclarer l'échec"),
        ),
      ],
    );
  }
}

/// Ouvre une liste de reproducteurs avec recherche (nom, matricule, race) et
/// renvoie celui choisi, ou `null` si l'utilisateur annule.
Future<Rabbit?> _pickReproducer(
  BuildContext context, {
  required String title,
  required List<Rabbit> rabbits,
  required Color accentColor,
}) {
  return showModalBottomSheet<Rabbit>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder:
        (ctx) => _ReproducerPickerSheet(
          title: title,
          rabbits: rabbits,
          accentColor: accentColor,
        ),
  );
}

/// Champ façon "select" qui ouvre le picker avec recherche au lieu d'un
/// menu déroulant classique.
class _ReproducerField extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final Rabbit? selected;
  final VoidCallback onTap;

  const _ReproducerField({
    super.key,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: accentColor),
          suffixIcon: const Icon(Icons.search, size: 20),
        ),
        child: Text(
          selected != null
              ? '${selected!.name} (${selected!.tagNumber})'
              : 'Choisir…',
          style: TextStyle(
            color:
                selected != null ? AppColors.textPrimary : AppColors.textMuted,
            fontWeight: selected != null ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ReproducerPickerSheet extends StatefulWidget {
  final String title;
  final List<Rabbit> rabbits;
  final Color accentColor;

  const _ReproducerPickerSheet({
    required this.title,
    required this.rabbits,
    required this.accentColor,
  });

  @override
  State<_ReproducerPickerSheet> createState() => _ReproducerPickerSheetState();
}

class _ReproducerPickerSheetState extends State<_ReproducerPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered =
        widget.rabbits.where((r) {
          if (_query.isEmpty) return true;
          final q = _query.toLowerCase();
          return r.name.toLowerCase().contains(q) ||
              r.tagNumber.toLowerCase().contains(q) ||
              r.breed.toLowerCase().contains(q);
        }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('reproducer-search'),
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 20),
                  hintText: 'Rechercher par nom, matricule, race...',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              Expanded(
                child:
                    filtered.isEmpty
                        ? const Center(
                          child: Text(
                            'Aucun reproducteur trouvé.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                        : ListView.separated(
                          controller: scrollController,
                          itemCount: filtered.length,
                          separatorBuilder:
                              (_, __) => const Divider(
                                height: 1,
                                color: Color(0xFFEDEFED),
                              ),
                          itemBuilder: (_, i) {
                            final r = filtered[i];
                            return ListTile(
                              key: ValueKey('reproducer-option-${r.id}'),
                              onTap: () => Navigator.pop(context, r),
                              leading: CircleAvatar(
                                backgroundColor: widget.accentColor.withAlpha(
                                  30,
                                ),
                                child: Text(
                                  r.name.isNotEmpty
                                      ? r.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: widget.accentColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              title: Text(
                                r.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text('${r.tagNumber} • ${r.breed}'),
                            );
                          },
                        ),
              ),
            ],
          ),
        );
      },
    );
  }
}
