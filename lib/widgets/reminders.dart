import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/care.dart';
import '../providers/rabbit_provider.dart';
import '../screens/care_screen.dart';
import '../screens/matings_screen.dart';
import '../screens/rabbit_detail_screen.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import 'care_sheets.dart';
import 'litter_form.dart';

final _dateFmt = DateFormat('dd MMMM yyyy', 'fr_FR');

const _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
);

/// Une action à mener : palpation à faire, mise bas à enregistrer, ou soin dû.
/// Affichée dans le rappel de la page d'accueil et sur la page Activité.
class ReminderItem {
  final IconData icon;
  final Color bg;
  final Color fg;
  final String title;
  final String subtitle;
  final String actionLabel;

  /// Jours avant l'échéance (négatif = en retard).
  final int daysUntilDue;
  final void Function(BuildContext context, RabbitProvider provider) onAction;

  /// Explication affichée dans le bottom sheet de détail.
  final String detail;

  /// Bouton secondaire optionnel du bottom sheet (ex. "Voir les accouplements").
  final String? viewLabel;
  final void Function(BuildContext context, RabbitProvider provider)?
  onViewDetail;

  ReminderItem({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.daysUntilDue,
    required this.onAction,
    required this.detail,
    this.viewLabel,
    this.onViewDetail,
  });

  String get dueLabel {
    if (daysUntilDue < 0) return 'En retard de ${-daysUntilDue} j';
    if (daysUntilDue == 0) return 'Aujourd\'hui';
    if (daysUntilDue == 1) return 'Demain';
    return 'Dans $daysUntilDue j';
  }
}

int _daysUntil(DateTime date) {
  final today = DateTime.now();
  final day = DateTime(today.year, today.month, today.day);
  final target = DateTime(date.year, date.month, date.day);
  return target.difference(day).inDays;
}

/// Liste complète des actions à mener (palpations non faites, mises bas
/// enregistrables, soins dus), triée par urgence (la plus pressante d'abord).
/// Pas de limite de date ici : c'est à l'appelant de ne garder que les
/// prochains jours s'il le souhaite (voir le rappel de la page d'accueil).
List<ReminderItem> buildReminders(RabbitProvider provider) {
  final items = <ReminderItem>[];

  for (final m in provider.matingsAwaitingKindling) {
    final female = provider.getRabbitById(m.femaleId)?.name ?? 'Femelle';
    final male = provider.getRabbitById(m.maleId)?.name ?? 'Mâle';

    if (!m.palpationDone) {
      items.add(
        ReminderItem(
          icon: Icons.science_outlined,
          bg: AppColors.statusPregnantBg,
          fg: AppColors.statusPregnantText,
          title: 'Palpation à faire',
          subtitle: '$female × $male',
          actionLabel: 'Palpation effectuée',
          daysUntilDue: _daysUntil(m.palpationDate),
          onAction: (context, p) => confirmMatingPalpation(context, p, m),
          detail:
              'La palpation permet de confirmer si $female est gestante. '
              'Prévue le ${_dateFmt.format(m.palpationDate)} (12 jours après '
              'la saillie du ${_dateFmt.format(m.matingDate)} avec $male).'
              '${m.shouldInstallNestBox ? '\n\nLa boîte à nid devrait déjà être installée (prévue le ${_dateFmt.format(m.nestBoxDate)}).' : ''}'
              '\n\nSi la gestation est confirmée, la mise bas est attendue '
              'vers le ${_dateFmt.format(m.expectedKindlingDate)}.',
          viewLabel: 'Voir les accouplements',
          onViewDetail:
              (context, p) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MatingsScreen(initialTab: 0),
                ),
              ),
        ),
      );
    }
    if (m.canRegisterKindling) {
      items.add(
        ReminderItem(
          icon: Icons.child_friendly_outlined,
          bg: AppColors.statusAlertBg,
          fg: AppColors.statusAlertText,
          title: 'Mise bas à enregistrer',
          subtitle: '$female × $male',
          actionLabel: 'Mise bas enregistrée',
          daysUntilDue: _daysUntil(m.expectedKindlingDate),
          onAction: (context, p) => showLitterForm(context, p, mating: m),
          detail:
              'La mise bas de $female × $male est attendue vers le '
              '${_dateFmt.format(m.expectedKindlingDate)} (J${m.gestationDay} '
              'de gestation, saillie du ${_dateFmt.format(m.matingDate)}).'
              '${m.shouldInstallNestBox ? '\n\nLa boîte à nid devrait être installée depuis le ${_dateFmt.format(m.nestBoxDate)}.' : ''}'
              '\n\nDès que la mise bas a eu lieu, enregistrez-la pour créer '
              'la portée.',
          viewLabel: 'Voir les accouplements',
          onViewDetail:
              (context, p) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MatingsScreen(initialTab: 0),
                ),
              ),
        ),
      );
    }
  }

  for (final c in provider.upcomingCares) {
    final overdue = c.status == DueStatus.overdue;
    final rabbitNames =
        c.rabbits.isEmpty ? null : c.rabbits.map((r) => r.name).join(', ');
    items.add(
      ReminderItem(
        icon: Icons.medical_services_outlined,
        bg: overdue ? AppColors.statusAlertBg : AppColors.statusPregnantBg,
        fg: overdue ? AppColors.statusAlertText : AppColors.statusPregnantText,
        title: c.treatmentName,
        subtitle: rabbitNames ?? 'Tout le cheptel',
        actionLabel: 'Soin effectué',
        daysUntilDue: c.daysUntilDue,
        onAction:
            (context, p) => showCareRecordSheet(
              context,
              treatmentId: c.treatmentId,
              rabbitIds: c.rabbits.map((r) => r.id).toList(),
              purpose: c.purpose,
            ),
        detail:
            'Le soin « ${c.treatmentName} » (${c.category.label}) est prévu '
            'le ${_dateFmt.format(c.dueDate)}. Dernier soin effectué le '
            '${_dateFmt.format(c.lastDate)}.'
            '${c.purpose.isNotEmpty ? '\n\nMotif : ${c.purpose}' : ''}'
            '\n\nConcerne : ${rabbitNames ?? 'tout le cheptel'}.',
        viewLabel: c.rabbits.length == 1 ? 'Voir la fiche' : 'Voir les soins',
        onViewDetail: (context, p) {
          if (c.rabbits.length == 1) {
            final rabbit = p.getRabbitById(c.rabbits.first.id);
            if (rabbit != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RabbitDetailScreen(rabbit: rabbit),
                ),
              );
              return;
            }
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CareScreen(initialTab: 0)),
          );
        },
      ),
    );
  }

  items.sort((a, b) => a.daysUntilDue.compareTo(b.daysUntilDue));
  return items;
}

/// Carte d'une action à mener, avec son bouton pour la marquer faite.
class ReminderCard extends StatelessWidget {
  final ReminderItem item;
  final RabbitProvider provider;
  final double width;

  const ReminderCard({
    super.key,
    required this.item,
    required this.provider,
    this.width = 220,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap:
            () => showReminderDetailSheet(
              context,
              item: item,
              provider: provider,
            ),
        child: Ink(
          width: width,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(6),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: item.bg,
                      border: Border.all(color: item.fg),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.icon, size: 18, color: item.fg),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: item.bg,
                      border: Border.all(color: item.fg),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.dueLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: item.fg,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => item.onAction(context, provider),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    item.actionLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Détail d'une action à mener, ouvert en tapant sur sa carte (accueil ou
/// page Activité). Même convention que les autres feuilles de l'app
/// (care_sheets.dart, matings_screen.dart::_showMatingTimeline) : fond
/// blanc, coin haut 24px, défilable.
void showReminderDetailSheet(
  BuildContext context, {
  required ReminderItem item,
  required RabbitProvider provider,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: _sheetShape,
    builder:
        (ctx) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: item.bg,
                        border: Border.all(color: item.fg),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item.icon, size: 18, color: item.fg),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.subtitle,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: item.bg,
                    border: Border.all(color: item.fg),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.dueLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: item.fg,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  item.detail,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (item.onViewDetail != null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            item.onViewDetail!(context, provider);
                          },
                          child: Text(item.viewLabel!),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          item.onAction(context, provider);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        child: Text(item.actionLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
  );
}
