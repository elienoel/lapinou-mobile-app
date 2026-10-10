import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/litter.dart';
import '../models/rabbit.dart';
import '../providers/auth_provider.dart';
import '../providers/rabbit_provider.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import '../widgets/litter_sheets.dart';
import 'rabbit_detail_screen.dart';
import '../widgets/app_icon.dart';

enum _LitterFilter { all, atNest, toWean, weaned }

/// Liste des portées (onglet « Mises bas » de l'écran Accouplements & Mises bas) :
/// résumé, filtres, cartes détaillées, sevrage et modification.
class LittersView extends StatefulWidget {
  const LittersView({super.key});

  @override
  State<LittersView> createState() => _LittersViewState();
}

class _LittersViewState extends State<LittersView> {
  _LitterFilter _filter = _LitterFilter.all;

  bool _matches(Litter l) {
    switch (_filter) {
      case _LitterFilter.all:
        return true;
      case _LitterFilter.atNest:
        return l.status != LitterStatus.weaned;
      case _LitterFilter.toWean:
        return l.status == LitterStatus.weaningDue;
      case _LitterFilter.weaned:
        return l.status == LitterStatus.weaned;
    }
  }

  Future<void> _wean(Litter lit) async {
    final messenger = ScaffoldMessenger.of(context);
    final before = context.read<RabbitProvider>().rabbits.length;
    final done = await showWeanLitterSheet(context, lit);
    if (done != true || !mounted) return;
    final created = context.read<RabbitProvider>().rabbits.length - before;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          created > 0
              ? 'Sevrage enregistré · $created fiche${created > 1 ? 's' : ''} lapin créée${created > 1 ? 's' : ''}'
              : 'Sevrage enregistré',
        ),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _confirmDelete(Litter lit) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<RabbitProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Supprimer cette mise bas ?'),
            content: const Text(
              "L'accouplement lié repassera en cours. Cette action est définitive.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );
    if (ok != true || !mounted) return;
    await provider.deleteLitter(lit);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Mise bas supprimée'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _edit(Litter lit) async {
    final messenger = ScaffoldMessenger.of(context);
    final done = await showEditLitterSheet(context, lit);
    if (done == true) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Portée mise à jour'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RabbitProvider>(
      builder: (context, provider, child) {
        final all = provider.litters;
        final totalKits = provider.totalKitsInNests;
        final atNestCount =
            all.where((l) => l.status != LitterStatus.weaned).length;
        final toWeanCount = provider.littersToWeanCount;
        final weanedCount =
            all.where((l) => l.status == LitterStatus.weaned).length;
        final shown = all.where(_matches).toList();

        return RefreshIndicator(
          onRefresh: () async {
            final token = context.read<AuthProvider>().token;
            await Future.wait([
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
                _buildSummary(totalKits, atNestCount, toWeanCount),
                const SizedBox(height: 18),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _chip(_LitterFilter.all, 'Toutes (${all.length})'),
                      const SizedBox(width: 8),
                      _chip(_LitterFilter.atNest, 'Au nid ($atNestCount)'),
                      const SizedBox(width: 8),
                      _chip(_LitterFilter.toWean, 'À sevrer ($toWeanCount)'),
                      const SizedBox(width: 8),
                      _chip(_LitterFilter.weaned, 'Sevrées ($weanedCount)'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (shown.isEmpty)
                  _buildEmptyLitters(all.isEmpty)
                else
                  ...shown.map(
                    (lit) => _buildLitterItem(context, lit, provider),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chip(_LitterFilter value, String label) {
    final selected = _filter == value;
    return InkWell(
      key: ValueKey('litter-filter-${value.name}'),
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

  Widget _buildSummary(int kits, int atNest, int toWean) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(50),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const AppIcon(
              AppIcons.nest,
              size: 46,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LAPEREAUX AU NID',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$kits lapereau${kits > 1 ? 'x' : ''}',
                  key: const ValueKey('kits-total'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$atNest portée${atNest > 1 ? 's' : ''} au nid'
                  '${toWean > 0 ? ' · $toWean à sevrer' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withAlpha(220),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _parentLink(
    BuildContext context,
    Rabbit? rabbit,
    String symbol,
    String fallback,
  ) {
    final label = '$symbol ${rabbit?.name ?? fallback}';
    final style = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: rabbit == null ? AppColors.textSecondary : AppColors.primary,
    );
    if (rabbit == null) return Text(label, style: style);
    return InkWell(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RabbitDetailScreen(rabbit: rabbit),
            ),
          ),
      child: Text(label, style: style),
    );
  }

  Widget _buildLitterItem(
    BuildContext context,
    Litter lit,
    RabbitProvider provider,
  ) {
    final mother = provider.getRabbitById(lit.motherId);
    final father = provider.getRabbitById(lit.fatherId);
    final status = lit.status;
    final cage = provider.getCageById(mother?.cageId);
    final losses = lit.stillBorn + lit.diedCount;

    final (badgeBg, badgeFg, badgeText) = switch (status) {
      LitterStatus.nursing => (
        AppColors.statusPregnantBg,
        AppColors.statusPregnantText,
        'Au nid',
      ),
      LitterStatus.weaningDue => (
        AppColors.statusAlertBg,
        AppColors.statusAlertText,
        'Sevrage à faire',
      ),
      LitterStatus.weaned => (
        AppColors.statusActiveBg,
        AppColors.statusActiveText,
        'Sevrée',
      ),
    };

    final d = lit.daysUntilWeaning;
    final weaningLine = switch (status) {
      LitterStatus.weaned =>
        lit.weanedAt != null
            ? 'Sevrée le ${DateFormat('dd/MM/yyyy').format(lit.weanedAt!)}'
            : 'Sevrage terminé',
      LitterStatus.weaningDue =>
        d == 0
            ? 'Sevrage à faire aujourd\'hui'
            : 'Sevrage en retard de ${-d} j',
      LitterStatus.nursing => 'Sevrage dans $d j',
    };

    return Container(
      key: ValueKey('litter-${lit.id}'),
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AppIcon(
                  AppIcons.nest,
                  size: 28,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Portée de ${mother?.name ?? 'Mère'}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
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
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _parentLink(context, mother, '♀', 'Mère inconnue'),
                const Text('×', style: TextStyle(color: AppColors.textMuted)),
                _parentLink(context, father, '♂', 'Père inconnu'),
              ],
            ),
            if (cage != null && mother?.compartmentNumber != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '📍 Cage ${cage.name} · loge ${mother!.compartmentNumber}',
                  key: ValueKey('litter-location-${lit.id}'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.scaffoldBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatPill(
                    'NÉS VIVANTS',
                    '${lit.bornAlive}',
                    AppColors.textPrimary,
                  ),
                  _buildStatPill(
                    'AU NID',
                    '${lit.kitsRemaining}',
                    AppColors.primary,
                  ),
                  _buildStatPill('SEVRÉS', '${lit.weaned}', AppColors.maleBlue),
                  _buildStatPill(
                    'PERTES',
                    '$losses',
                    losses > 0 ? Colors.redAccent : Colors.grey,
                  ),
                ],
              ),
            ),
            if (losses > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${lit.stillBorn} mort-né${lit.stillBorn > 1 ? 's' : ''} · ${lit.diedCount} mort${lit.diedCount > 1 ? 's' : ''} au nid',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Flexible(
                  child: Text(
                    'Né le ${DateFormat('dd/MM/yyyy').format(lit.birthDate)} · J${lit.ageDays}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Sevrage prévu le ${DateFormat('dd/MM').format(lit.calculatedWeaningDate)}',
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: status == LitterStatus.weaned ? 1 : lit.weaningProgress,
                minHeight: 7,
                backgroundColor: AppColors.primarySoftBorder,
                valueColor: AlwaysStoppedAnimation(
                  status == LitterStatus.weaningDue
                      ? AppColors.statusAlertText
                      : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              weaningLine,
              key: ValueKey('litter-weaning-line-${lit.id}'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color:
                    status == LitterStatus.weaningDue
                        ? AppColors.statusAlertText
                        : AppColors.primary,
              ),
            ),
            if (lit.notes != null && lit.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Notes: ${lit.notes}',
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (status != LitterStatus.weaned)
                  Expanded(
                    child: FilledButton.icon(
                      key: ValueKey('wean-${lit.id}'),
                      onPressed: () => _wean(lit),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      icon: const Icon(Icons.call_split_rounded, size: 18),
                      label: const Text('Sevrer'),
                    ),
                  ),
                if (status != LitterStatus.weaned) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: ValueKey('edit-${lit.id}'),
                    onPressed: () => _edit(lit),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Modifier'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: ValueKey('delete-${lit.id}'),
                  tooltip: 'Supprimer la mise bas',
                  onPressed: () => _confirmDelete(lit),
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyLitters(bool noneAtAll) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          const AppIcon(AppIcons.nest, size: 56, color: AppColors.primary),
          const SizedBox(height: 10),
          Text(
            noneAtAll
                ? 'Aucune mise bas enregistrée pour le moment.'
                : 'Aucune portée dans cette catégorie.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (noneAtAll) ...[
            const SizedBox(height: 4),
            const Text(
              "Enregistrez une mise bas depuis la carte d'un accouplement ou avec le bouton ci-dessous.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
