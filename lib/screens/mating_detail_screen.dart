import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/litter.dart';
import '../models/mating.dart';
import '../models/rabbit.dart';
import '../providers/breeding_settings_provider.dart';
import '../providers/rabbit_provider.dart';
import '../theme/colors.dart';
import '../utils/formatters.dart';
import '../widgets/app_ui.dart';
import '../widgets/litter_form.dart';
import '../widgets/litter_sheets.dart';
import '../widgets/pair_avatars.dart';
import 'matings_screen.dart';
import 'rabbit_detail_screen.dart';

/// Détail d'un accouplement, suivi étape par étape :
/// saillie → palpation → boîte à nid → mise bas → sevrage → réussi.
/// Chaque étape en cours propose son action. Sert aussi aux anciennes
/// portées enregistrées sans accouplement ([litterId] seul).
class MatingDetailScreen extends StatelessWidget {
  const MatingDetailScreen({super.key, this.matingId, this.litterId})
    : assert(matingId != null || litterId != null);

  final String? matingId;
  final String? litterId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RabbitProvider>();
    final m = provider.getMatingById(matingId);
    final litter =
        m != null
            ? provider.litterOfMating(m.id)
            : provider.getLitterById(litterId);

    // Supprimé entre-temps
    if (m == null && litter == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Cet accouplement n’existe plus.')),
      );
    }

    final female = provider.getRabbitById(m?.femaleId ?? litter!.motherId);
    final male = provider.getRabbitById(m?.maleId ?? litter!.fatherId);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(m != null ? 'Accouplement' : 'Mise bas'),
        actions: [
          if (m != null)
            PopupMenuButton<String>(
              key: const ValueKey('mating-menu'),
              tooltip: 'Options',
              onSelected: (v) async {
                if (v == 'edit') showMatingForm(context, provider, existing: m);
                if (v == 'fail') confirmMatingFailure(context, provider, m);
                if (v == 'delete') {
                  final done = await confirmDeleteMating(context, provider, m);
                  if (done && context.mounted) Navigator.pop(context);
                }
              },
              itemBuilder:
                  (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    if (m.isActive)
                      const PopupMenuItem(
                        value: 'fail',
                        child: Text('Déclarer un échec'),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Supprimer',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          _Header(mating: m, litter: litter, female: female, male: male),
          const SizedBox(height: 18),
          const Text(
            'Étapes',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (m != null) ..._matingSteps(context, provider, m, litter),
          if (m == null)
            ..._litterSteps(context, provider, litter!, last: true),
          if ((m?.notes ?? litter?.notes)?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: appCardDecoration(),
              child: Text(
                m?.notes ?? litter!.notes!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _matingSteps(
    BuildContext context,
    RabbitProvider provider,
    Mating m,
    Litter? litter,
  ) {
    final settings = context.watch<BreedingSettingsProvider>().settings;
    final failed = m.status == MatingStatus.failed;
    final completed = m.status == MatingStatus.completed;

    // Palpation
    final _StepState palpationState;
    final String palpationText;
    if (m.palpationDone) {
      palpationState = _StepState.done;
      palpationText =
          m.palpationDoneAt != null
              ? 'Positive · le ${formatDate(m.palpationDoneAt!)}'
              : 'Positive';
    } else if (failed) {
      palpationState = _StepState.failed;
      palpationText = 'Négative ou non faite';
    } else if (m.isActive) {
      palpationState = _StepState.current;
      palpationText =
          'Prévue vers le ${formatDate(m.palpationDateWith(settings.palpationDays))} (J${settings.palpationDays})';
    } else {
      palpationState = _StepState.skipped;
      palpationText = 'Non renseignée';
    }

    // Boîte à nid
    final _StepState nestState;
    final String nestText;
    if (m.nestBoxDone) {
      nestState = _StepState.done;
      nestText = 'Posée le ${formatDate(m.nestBoxDoneAt!)}';
    } else if (m.isActive) {
      nestState = m.palpationDone ? _StepState.current : _StepState.upcoming;
      nestText =
          'À poser vers le ${formatDate(m.nestBoxDateWith(settings.nestBoxDaysBeforeKindling))} (J${settings.nestBoxDayOfCycle})';
    } else {
      nestState = failed ? _StepState.upcoming : _StepState.skipped;
      nestText = failed ? '—' : 'Non renseignée';
    }

    return [
      _Step(
        icon: Icons.favorite_outline,
        state: _StepState.done,
        title: 'Saillie',
        subtitle: 'Le ${formatDate(m.matingDate)}',
      ),
      _Step(
        icon: Icons.touch_app_outlined,
        state: palpationState,
        title: 'Palpation',
        subtitle: palpationText,
        actions: [
          if (palpationState == _StepState.current) ...[
            _action(
              key: ValueKey('palpation-positive-${m.id}'),
              label: 'Positive',
              icon: Icons.check_rounded,
              onPressed: () => confirmMatingPalpation(context, provider, m),
            ),
            _action(
              key: ValueKey('palpation-negative-${m.id}'),
              label: 'Négative',
              icon: Icons.close_rounded,
              outlined: true,
              danger: true,
              onPressed:
                  () => confirmMatingFailure(
                    context,
                    provider,
                    m,
                    initialReason: 'Palpation négative',
                  ),
            ),
          ],
        ],
      ),
      _Step(
        icon: Icons.inventory_2_outlined,
        state: nestState,
        title: 'Pose de la boîte à nid',
        subtitle: nestText,
        actions: [
          if (m.isActive && !m.nestBoxDone)
            _action(
              key: ValueKey('nestbox-${m.id}'),
              label: 'Boîte posée',
              icon: Icons.check_rounded,
              outlined: !m.palpationDone,
              onPressed: () => confirmMatingNestBox(context, provider, m),
            ),
        ],
      ),
      if (litter != null)
        ..._litterSteps(context, provider, litter, last: false)
      else ...[
        _Step(
          icon: Icons.child_friendly_outlined,
          state:
              failed
                  ? _StepState.upcoming
                  : (m.isActive ? _StepState.current : _StepState.upcoming),
          title: 'Mise bas',
          subtitle:
              failed
                  ? '—'
                  : 'Prévue le ${formatDate(m.expectedKindlingDateWith(settings.gestationDays))} (J${settings.gestationDays})',
          actions: [
            if (m.isActive)
              _action(
                key: ValueKey('kindle-${m.id}'),
                label: 'Enregistrer la mise bas',
                icon: Icons.child_friendly_outlined,
                onPressed:
                    m.canRegisterKindling
                        ? () => showLitterForm(context, provider, mating: m)
                        : null,
              ),
          ],
          footer:
              m.isActive && !m.canRegisterKindling
                  ? Text(
                    'Possible à partir du ${formatDate(m.earliestKindlingDate)} '
                    '(${Mating.minGestationDays} jours après la saillie).',
                    key: ValueKey('kindle-hint-${m.id}'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  )
                  : null,
        ),
        const _Step(
          icon: Icons.call_split_rounded,
          state: _StepState.upcoming,
          title: 'Sevrage',
          subtitle: 'Après la mise bas, vers 45 jours',
        ),
      ],
      _Step(
        icon: Icons.emoji_events_outlined,
        state:
            completed
                ? _StepState.done
                : failed
                ? _StepState.failed
                : (litter?.isWeaned == true
                    ? _StepState.current
                    : _StepState.upcoming),
        title: failed ? 'Non réussi' : 'Réussi',
        subtitle:
            completed
                ? 'Accouplement terminé avec succès'
                : failed
                ? 'Accouplement terminé sans portée'
                : 'Une fois toute la portée sevrée',
        isLast: true,
        actions: [
          if (m.status == MatingStatus.kindled && litter?.isWeaned == true)
            _action(
              key: ValueKey('complete-${m.id}'),
              label: 'Marquer comme réussi',
              icon: Icons.emoji_events_outlined,
              onPressed: () => confirmMatingSuccess(context, provider, m),
            ),
        ],
      ),
    ];
  }

  /// Étapes mise bas et sevrage d'une portée enregistrée.
  List<Widget> _litterSteps(
    BuildContext context,
    RabbitProvider provider,
    Litter litter, {
    required bool last,
  }) {
    final mother = provider.getRabbitById(litter.motherId);
    final cage = provider.getCageById(mother?.cageId);
    final losses = litter.stillBorn + litter.diedCount;
    final d = litter.daysUntilWeaning;
    final weaningLine = switch (litter.status) {
      LitterStatus.weaned =>
        litter.weanedAt != null
            ? 'Sevrage terminé le ${formatDate(litter.weanedAt!)}'
            : 'Sevrage terminé',
      LitterStatus.weaningDue =>
        d == 0 ? 'Sevrage à faire aujourd’hui' : 'Sevrage en retard de ${-d} j',
      LitterStatus.nursing =>
        'Prévu le ${formatDate(litter.calculatedWeaningDate)} · dans $d j',
    };

    return [
      _Step(
        icon: Icons.child_friendly_outlined,
        state: _StepState.done,
        title: 'Mise bas',
        subtitle:
            'Le ${formatDate(litter.birthDate)} · ${litter.bornAlive} né${litter.bornAlive > 1 ? 's' : ''} vivant${litter.bornAlive > 1 ? 's' : ''}'
            '${litter.stillBorn > 0 ? ' · ${litter.stillBorn} mort-né${litter.stillBorn > 1 ? 's' : ''}' : ''}',
        actions: [
          _action(
            key: ValueKey('edit-${litter.id}'),
            label: 'Modifier la portée',
            icon: Icons.edit_outlined,
            outlined: true,
            onPressed: () async {
              final done = await showEditLitterSheet(context, litter);
              if (done == true && context.mounted) {
                showAppSnack(context, 'Portée mise à jour');
              }
            },
          ),
          IconButton(
            key: ValueKey('delete-${litter.id}'),
            tooltip: 'Supprimer la mise bas',
            onPressed: () => _confirmDeleteLitter(context, provider, litter),
            icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
          ),
        ],
      ),
      _Step(
        icon: Icons.call_split_rounded,
        state:
            litter.isWeaned
                ? _StepState.done
                : (litter.status == LitterStatus.weaningDue
                    ? _StepState.alert
                    : _StepState.current),
        title: 'Sevrage',
        subtitle: weaningLine,
        subtitleKey: ValueKey('litter-weaning-line-${litter.id}'),
        isLast: last,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Row(
              children: [
                _stat('Au nid', '${litter.kitsRemaining}', AppColors.secondary),
                _stat('Sevrés', '${litter.weaned}', AppColors.maleBlue),
                _stat(
                  'Pertes',
                  '$losses',
                  losses > 0 ? Colors.redAccent : AppColors.textMuted,
                ),
              ],
            ),
            if (!litter.isWeaned) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: litter.weaningProgress,
                  minHeight: 6,
                  backgroundColor: AppColors.secondarySoft,
                  valueColor: AlwaysStoppedAnimation(
                    litter.status == LitterStatus.weaningDue
                        ? AppColors.statusAlertText
                        : AppColors.secondary,
                  ),
                ),
              ),
            ],
            if (cage != null && mother?.compartmentNumber != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InkWell(
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RabbitDetailScreen(rabbit: mother),
                        ),
                      ),
                  child: Text(
                    'Avec ${mother!.name} · cage ${cage.name}, loge ${mother.compartmentNumber}',
                    key: ValueKey('litter-location-${litter.id}'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          if (!litter.isWeaned)
            _action(
              key: ValueKey('wean-${litter.id}'),
              label: 'Sevrer',
              icon: Icons.call_split_rounded,
              onPressed: () => _wean(context, litter),
            ),
        ],
      ),
    ];
  }

  Future<void> _wean(BuildContext context, Litter litter) async {
    final provider = context.read<RabbitProvider>();
    final before = provider.rabbits.length;
    final done = await showWeanLitterSheet(context, litter);
    if (done != true || !context.mounted) return;
    final created = provider.rabbits.length - before;
    showAppSnack(
      context,
      created > 0
          ? 'Sevrage enregistré · $created fiche${created > 1 ? 's' : ''} lapin créée${created > 1 ? 's' : ''}'
          : 'Sevrage enregistré',
    );
  }

  Future<void> _confirmDeleteLitter(
    BuildContext context,
    RabbitProvider provider,
    Litter litter,
  ) async {
    final ok = await confirmAction(
      context,
      title: 'Supprimer cette mise bas ?',
      message:
          "L'accouplement lié repassera en gestation. Cette action est définitive.",
      destructive: true,
    );
    if (ok != true || !context.mounted) return;
    await provider.deleteLitter(litter);
    if (!context.mounted) return;
    showAppSnack(context, 'Mise bas supprimée');
    if (litter.matingId == null) Navigator.pop(context);
  }

  static Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _action({
    required Key key,
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool outlined = false,
    bool danger = false,
  }) {
    final color = danger ? Colors.red.shade700 : AppColors.primary;
    if (outlined) {
      return OutlinedButton.icon(
        key: key,
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withAlpha(120)),
          shape: const StadiumBorder(),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
    }
    return FilledButton.icon(
      key: key,
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

/// En-tête : les deux lapins, leurs noms et où en est le suivi.
class _Header extends StatelessWidget {
  const _Header({
    required this.mating,
    required this.litter,
    required this.female,
    required this.male,
  });

  final Mating? mating;
  final Litter? litter;
  final Rabbit? female;
  final Rabbit? male;

  @override
  Widget build(BuildContext context) {
    final m = mating;
    final (value, caption, color) = matingStage(m, litter);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(shadow: true),
      child: Row(
        children: [
          PairAvatars(female: female, male: male, size: 60),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${female?.name ?? 'Femelle'} ♀',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '× ${male?.name ?? 'Mâle'} ♂',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  m != null
                      ? (m.isActive
                          ? 'J${m.gestationDay} de gestation'
                          : m.statusLabel)
                      : 'Portée sans accouplement enregistré',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                caption,
                style: TextStyle(fontSize: 11, color: color.withAlpha(200)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _StepState { done, current, alert, upcoming, skipped, failed }

/// Une étape de la frise : pastille, titre, détail, et ses actions quand
/// c'est l'étape en cours.
class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.state,
    required this.title,
    required this.subtitle,
    this.subtitleKey,
    this.actions = const [],
    this.body,
    this.footer,
    this.isLast = false,
  });

  final IconData icon;
  final _StepState state;
  final String title;
  final String subtitle;
  final Key? subtitleKey;
  final List<Widget> actions;
  final Widget? body;
  final Widget? footer;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg, IconData glyph) = switch (state) {
      _StepState.done => (
        AppColors.statusActiveText,
        AppColors.statusActiveText.withAlpha(25),
        Icons.check_rounded,
      ),
      _StepState.failed => (
        AppColors.statusAlertText,
        AppColors.statusAlertText.withAlpha(25),
        Icons.close_rounded,
      ),
      _StepState.alert => (
        AppColors.statusAlertText,
        AppColors.statusAlertText.withAlpha(25),
        icon,
      ),
      _StepState.current => (Colors.white, AppColors.secondary, icon),
      _StepState.upcoming || _StepState.skipped => (
        AppColors.textMuted,
        AppColors.secondarySoft,
        icon,
      ),
    };
    final emphasized = state == _StepState.current || state == _StepState.alert;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pastille et trait de liaison
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                  child: Icon(glyph, size: 18, color: fg),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.cardBorder,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18, top: 6),
              child: Container(
                padding: emphasized ? const EdgeInsets.all(14) : null,
                decoration: emphasized ? appCardDecoration(shadow: true) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color:
                            state == _StepState.upcoming ||
                                    state == _StepState.skipped
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      key: subtitleKey,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            state == _StepState.alert
                                ? FontWeight.w700
                                : FontWeight.w500,
                        color:
                            state == _StepState.alert ||
                                    state == _StepState.failed
                                ? AppColors.statusAlertText
                                : AppColors.textSecondary,
                      ),
                    ),
                    if (body != null) body!,
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: actions,
                      ),
                    ],
                    if (footer != null) ...[const SizedBox(height: 6), footer!],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
