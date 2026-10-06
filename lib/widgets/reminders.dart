import 'package:flutter/material.dart';

import '../models/care.dart';
import '../providers/rabbit_provider.dart';
import '../screens/matings_screen.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import 'care_sheets.dart';
import 'litter_form.dart';

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

  const ReminderItem({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.daysUntilDue,
    required this.onAction,
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
        ),
      );
    }
  }

  for (final c in provider.upcomingCares) {
    final overdue = c.status == DueStatus.overdue;
    items.add(
      ReminderItem(
        icon: Icons.medical_services_outlined,
        bg: overdue ? AppColors.statusAlertBg : AppColors.statusPregnantBg,
        fg: overdue ? AppColors.statusAlertText : AppColors.statusPregnantText,
        title: '${c.category.emoji} ${c.treatmentName}',
        subtitle:
            c.rabbits.isEmpty
                ? 'Tout le cheptel'
                : c.rabbits.map((r) => r.name).join(', '),
        actionLabel: 'Soin effectué',
        daysUntilDue: c.daysUntilDue,
        onAction:
            (context, p) => showCareRecordSheet(
              context,
              treatmentId: c.treatmentId,
              rabbitIds: c.rabbits.map((r) => r.id).toList(),
              purpose: c.purpose,
            ),
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
    return Container(
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
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
    );
  }
}
