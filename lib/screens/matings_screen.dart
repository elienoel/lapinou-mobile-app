import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/mating.dart';
import '../providers/auth_provider.dart';
import '../providers/rabbit_provider.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import '../widgets/litter_form.dart';
import 'litters_screen.dart';

enum _MatingFilter { active, finished, all }

/// Accouplements et mises bas sur une même page (deux onglets).
/// [initialTab] : 0 = accouplements, 1 = mises bas.
class MatingsScreen extends StatefulWidget {
  final int initialTab;

  const MatingsScreen({super.key, this.initialTab = 0});

  @override
  State<MatingsScreen> createState() => _MatingsScreenState();
}

class _MatingsScreenState extends State<MatingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  _MatingFilter _filter = _MatingFilter.active;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    // Le bouton flottant dépend de l'onglet affiché
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  static const _editableStatuses = [
    MatingStatus.pending,
    MatingStatus.confirmed,
    MatingStatus.failed,
    MatingStatus.kindled,
  ];

  static String _statusName(MatingStatus s) {
    switch (s) {
      case MatingStatus.pending:
        return 'En attente de palpation';
      case MatingStatus.confirmed:
        return 'Gestation confirmée';
      case MatingStatus.kindled:
        return 'Mise bas réalisée';
      case MatingStatus.failed:
        return 'Infructueux';
    }
  }

  /// Formulaire d'accouplement : création, ou modification si [existing] est fourni.
  void _showMatingDialog(
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
    MatingStatus selectedStatus = existing?.status ?? MatingStatus.pending;
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
            final expectedKindlingDate = matingDate.add(
              const Duration(days: 31),
            );

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
                    DropdownButtonFormField<String>(
                      value: selectedMaleId,
                      decoration: const InputDecoration(
                        labelText: 'Mâle reproducteur ♂',
                        prefixIcon: Icon(Icons.male, color: AppColors.maleBlue),
                      ),
                      items:
                          provider.males.map((m) {
                            return DropdownMenuItem(
                              value: m.id,
                              child: Text('${m.name} (${m.tagNumber})'),
                            );
                          }).toList(),
                      onChanged:
                          (val) => setModalState(() => selectedMaleId = val),
                    ),
                    const SizedBox(height: 12),

                    // Female selector
                    DropdownButtonFormField<String>(
                      value: selectedFemaleId,
                      decoration: const InputDecoration(
                        labelText: 'Femelle reproductrice ♀',
                        prefixIcon: Icon(
                          Icons.female,
                          color: AppColors.femalePink,
                        ),
                      ),
                      items:
                          provider.females.map((f) {
                            return DropdownMenuItem(
                              value: f.id,
                              child: Text('${f.name} (${f.tagNumber})'),
                            );
                          }).toList(),
                      onChanged:
                          (val) => setModalState(() => selectedFemaleId = val),
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
                                color:
                                    Colors.white,
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
                        border: Border.all(
                          color: AppColors.primarySoftBorder,
                        ),
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
                              _buildDialogMilestoneItem(
                                title: 'Palpation',
                                dayBadge: 'J+12',
                                date: DateFormat(
                                  'dd/MM',
                                  'fr_FR',
                                ).format(palpationDate),
                                isPassed: daysAgo >= 12,
                              ),
                              _buildDialogMilestoneItem(
                                title: 'Boîte à nid',
                                dayBadge: 'J+28',
                                date: DateFormat(
                                  'dd/MM',
                                  'fr_FR',
                                ).format(nestBoxDate),
                                isPassed: daysAgo >= 28,
                              ),
                              _buildDialogMilestoneItem(
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

                    if (isEdit) ...[
                      DropdownButtonFormField<MatingStatus>(
                        isExpanded: true,
                        value: selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Statut',
                          prefixIcon: Icon(
                            Icons.flag_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                        items:
                            _editableStatuses
                                .map(
                                  (st) => DropdownMenuItem(
                                    value: st,
                                    child: Text(_statusName(st)),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (val) => setModalState(
                              () => selectedStatus = val ?? selectedStatus,
                            ),
                      ),
                      const SizedBox(height: 12),
                    ],

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
                            if (isEdit) {
                              provider
                                  .updateMating(
                                    existing.copyWith(
                                      maleId: selectedMaleId,
                                      femaleId: selectedFemaleId,
                                      matingDate: matingDate,
                                      status: selectedStatus,
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
                                      : 'Accouplement du ${DateFormat('dd/MM/yyyy').format(matingDate)} enregistré (J${daysAgo + 1} de gestation) !',
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

  @override
  Widget build(BuildContext context) {
    return Consumer<RabbitProvider>(
      builder: (context, provider, child) {
        final activeCount = provider.matings.where((m) => m.isActive).length;
        final onMatings = _tabs.index == 0;

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
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.add_circle,
                  color: AppColors.primary,
                  size: 28,
                ),
                tooltip:
                    onMatings
                        ? 'Nouvel accouplement'
                        : 'Enregistrer une mise bas',
                onPressed:
                    () =>
                        onMatings
                            ? _showMatingDialog(context, provider)
                            : showLitterForm(context, provider),
              ),
            ],
            bottom: TabBar(
              controller: _tabs,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
              tabs: [
                Tab(text: 'Accouplements ($activeCount)'),
                Tab(text: 'Mises bas (${provider.litters.length})'),
              ],
            ),
          ),
          body: SafeArea(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildMatingsTab(context, provider),
                const LittersView(),
              ],
            ),
          ),
          floatingActionButton:
              onMatings
                  ? FloatingActionButton.extended(
                    heroTag: 'fab_matings',
                    onPressed: () => _showMatingDialog(context, provider),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.favorite),
                    label: const Text('Nouvel Accouplement'),
                  )
                  : FloatingActionButton.extended(
                    heroTag: 'fab_add_litter',
                    onPressed: () => showLitterForm(context, provider),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.add),
                    label: const Text('Enregistrer Mise Bas'),
                  ),
        );
      },
    );
  }

  // ---- Onglet Accouplements ----

  Widget _buildMatingsTab(BuildContext context, RabbitProvider provider) {
    final all = provider.matings;
    final active = all.where((m) => m.isActive).toList();
    final finished = all.where((m) => !m.isActive).toList();
    final shown = switch (_filter) {
      _MatingFilter.active => active,
      _MatingFilter.finished => finished,
      _MatingFilter.all => all,
    };

    return RefreshIndicator(
      onRefresh: () async {
        final token = context.read<AuthProvider>().token;
        await Future.wait([
          provider.fetchMatings(token: token),
          provider.fetchLitters(token: token),
          provider.fetchRabbits(token: token),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
              _buildEmptyMatings()
            else
              ...shown.map((m) => _buildMatingCard(context, m, provider)),
          ],
        ),
      ),
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

  // ---- Actions d'un accouplement ----

  Future<void> _confirmPalpation(
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
                          child: Text(DateFormat('dd/MM/yyyy').format(date)),
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
    if (ok != true || !mounted) return;

    final error = await provider.confirmPalpation(m, doneAt: date);
    if (!mounted) return;
    _snack(
      error ?? 'Palpation enregistrée : gestation confirmée',
      error: error != null,
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    RabbitProvider provider,
    Mating m,
  ) async {
    final female = provider.getRabbitById(m.femaleId);
    final male = provider.getRabbitById(m.maleId);

    // null = retour ; sinon le motif saisi (éventuellement vide)
    final reason = await showDialog<String>(
      context: context,
      builder:
          (ctx) => _CancelMatingDialog(
            summary:
                'La saillie ${female?.name ?? 'Femelle'} × ${male?.name ?? 'Mâle'} sera marquée « Infructueux » '
                'et la femelle redeviendra disponible.',
          ),
    );
    if (reason == null || !mounted) return;

    final error = await provider.cancelMating(m, reason: reason);
    if (!mounted) return;
    _snack(error ?? 'Saillie annulée', error: error != null);
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.primary,
        ),
      );
  }

  // ---- Carte d'un accouplement ----

  Widget _buildMatingCard(
    BuildContext context,
    Mating m,
    RabbitProvider provider,
  ) {
    final male = provider.getRabbitById(m.maleId);
    final female = provider.getRabbitById(m.femaleId);
    final active = m.isActive;

    final daysRemaining = m.daysUntilKindling;
    final progress = (m.gestationDay / 31.0).clamp(0.0, 1.0);

    final (badgeBg, badgeFg, badgeText) = switch (m.status) {
      MatingStatus.kindled => (
        AppColors.statusActiveBg,
        AppColors.statusActiveText,
        'Mise bas faite',
      ),
      MatingStatus.failed => (
        AppColors.statusAlertBg,
        AppColors.statusAlertText,
        'Infructueux',
      ),
      _ => (
        AppColors.statusPregnantBg,
        AppColors.statusPregnantText,
        'J${m.gestationDay} / 31',
      ),
    };

    return Container(
      key: ValueKey('mating-${m.id}'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🐰 ', style: TextStyle(fontSize: 18)),
              Expanded(
                child: Text(
                  '${female?.name ?? 'Femelle'} x ${male?.name ?? 'Mâle'}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  border: Border.all(color: badgeFg),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeFg,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                key: ValueKey('mating-menu-${m.id}'),
                tooltip: 'Options',
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textSecondary,
                ),
                onSelected: (v) {
                  if (v == 'edit') {
                    _showMatingDialog(context, provider, existing: m);
                  }
                  if (v == 'cancel') _confirmCancel(context, provider, m);
                },
                itemBuilder:
                    (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 20),
                            SizedBox(width: 10),
                            Flexible(child: Text('Modifier')),
                          ],
                        ),
                      ),
                      if (active)
                        PopupMenuItem(
                          value: 'cancel',
                          child: Row(
                            children: [
                              Icon(
                                Icons.cancel_outlined,
                                size: 20,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'Annuler la saillie',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
              ),
            ],
          ),
          if (active) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.primarySoft,
                valueColor: const AlwaysStoppedAnimation(
                  AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Progression gestation',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    daysRemaining > 0
                        ? 'Mise bas dans ~$daysRemaining j'
                        : 'Mise bas imminente !',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.scaffoldBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildDateRow(
                  'Date de saillie',
                  DateFormat('dd/MM/yyyy').format(m.matingDate),
                ),
                const SizedBox(height: 6),
                _buildDateRow(
                  m.palpationDoneAt != null || m.palpationDone
                      ? 'Palpation effectuée'
                      : 'Palpation (J12)',
                  DateFormat(
                    'dd/MM/yyyy',
                  ).format(m.palpationDoneAt ?? m.palpationDate),
                  isPast:
                      m.palpationDone ||
                      DateTime.now().isAfter(m.palpationDate),
                ),
                const SizedBox(height: 6),
                _buildDateRow(
                  'Pose Boîte à Nid (J28)',
                  DateFormat('dd/MM/yyyy').format(m.nestBoxDate),
                  isPast: DateTime.now().isAfter(m.nestBoxDate),
                  isAlert: active && m.shouldInstallNestBox,
                ),
                const SizedBox(height: 6),
                _buildDateRow(
                  'Mise bas estimée (J31)',
                  DateFormat('dd/MM/yyyy').format(m.expectedKindlingDate),
                  highlight: true,
                ),
              ],
            ),
          ),
          if (m.notes != null && m.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Note: ${m.notes}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (active) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!m.palpationDone)
                  OutlinedButton.icon(
                    key: ValueKey('palpation-${m.id}'),
                    onPressed: () => _confirmPalpation(context, provider, m),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Palpation effectuée'),
                  ),
                // Grisé tant que 21 jours ne se sont pas écoulés depuis la saillie
                FilledButton.icon(
                  key: ValueKey('kindle-${m.id}'),
                  onPressed:
                      m.canRegisterKindling
                          ? () => showLitterForm(context, provider, mating: m)
                          : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  icon: const Icon(Icons.child_friendly_outlined, size: 18),
                  label: const Text('Enregistrer la mise bas'),
                ),
              ],
            ),
            if (!m.canRegisterKindling)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Mise bas possible à partir du ${DateFormat('dd/MM/yyyy').format(m.earliestKindlingDate)} '
                  '(${Mating.minGestationDays} jours après la saillie).',
                  key: ValueKey('kindle-hint-${m.id}'),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyMatings() {
    final text = switch (_filter) {
      _MatingFilter.active => 'Aucun accouplement en cours.',
      _MatingFilter.finished => 'Aucun accouplement terminé.',
      _MatingFilter.all => 'Aucun accouplement enregistré.',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildDateRow(
    String label,
    String date, {
    bool isPast = false,
    bool isAlert = false,
    bool highlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              isPast ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 14,
              color: isPast ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color:
                    isAlert ? Colors.orange.shade800 : AppColors.textSecondary,
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        Text(
          date,
          style: TextStyle(
            fontSize: 12,
            fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
            color: highlight ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDialogMilestoneItem({
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
            color:
                isHighlight ? AppColors.primary : AppColors.textSecondary,
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
            isPassed ? '✓ Fait' : dayBadge,
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
                    : (isHighlight
                        ? AppColors.primary
                        : AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

/// Confirmation d'annulation d'une saillie, avec un motif facultatif.
/// Renvoie le motif (peut être vide) si on confirme, null si on revient en arrière.
class _CancelMatingDialog extends StatefulWidget {
  final String summary;

  const _CancelMatingDialog({required this.summary});

  @override
  State<_CancelMatingDialog> createState() => _CancelMatingDialogState();
}

class _CancelMatingDialogState extends State<_CancelMatingDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Annuler la saillie ?'),
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
          child: const Text('Annuler la saillie'),
        ),
      ],
    );
  }
}
