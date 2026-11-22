import 'package:intl/intl.dart';
import '../models/litter.dart';
import '../models/subscription.dart';
import '../providers/breeding_settings_provider.dart';
import '../providers/rabbit_provider.dart';
import 'reminder_notifications.dart';

final _dayMonth = DateFormat('dd/MM');

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Notifications de rappel de l'élevage, rédigées pour être comprises sans
/// ouvrir l'app, avec des rappels configurables par l'éleveur :
///
/// - palpation : le jour prévu (J12 par défaut) ou en avance selon [settings.palpationNoticeDays] ;
/// - boîte à nid : X jours avant la mise bas selon [settings.nestBoxDaysBeforeKindling], si non posée ;
/// - mise bas : la veille ou X jours avant selon [settings.kindlingNoticeDays] et le jour prévu ;
/// - sevrage : X jours avant selon [settings.weaningNoticeDays] et le jour prévu ;
/// - soins : la veille et le jour prévu.
List<ScheduledReminder> breedingNotifications(
  RabbitProvider provider, [
  BreedingSettings settings = BreedingSettings.defaults,
]) {
  final out = <ScheduledReminder>[];

  // Gestations en cours (sans mise bas enregistrée)
  for (final m in provider.matingsAwaitingKindling) {
    final female = provider.getRabbitById(m.femaleId)?.name ?? 'la femelle';
    final male = provider.getRabbitById(m.maleId)?.name ?? 'le mâle';

    // Dates calculées en fonction des réglages personnalisés
    final palpationDay = _day(m.palpationDateWith(settings.palpationDays));
    final kindling = _day(
      m.expectedKindlingDateWith(settings.gestationDays),
    );
    final nestBoxDay = _day(
      kindling.subtract(Duration(days: settings.nestBoxDaysBeforeKindling)),
    );

    if (!m.palpationDone) {
      // Rappel anticipé pour palpation si configuré
      if (settings.palpationNoticeDays > 0) {
        out.add(
          ScheduledReminder(
            title:
                'Palpation de $female dans ${settings.palpationNoticeDays} jour${settings.palpationNoticeDays > 1 ? 's' : ''}',
            body:
                'Pensez à préparer la palpation de $female (prévue le ${_dayMonth.format(palpationDay)}).',
            day: palpationDay.subtract(
              Duration(days: settings.palpationNoticeDays),
            ),
          ),
        );
      }

      out.add(
        ScheduledReminder(
          title: 'Palpation de $female',
          body:
              "C'est le moment de palper $female pour vérifier qu'elle est "
              'gestante (saillie avec $male le ${_dayMonth.format(m.matingDate)}).',
          day: palpationDay,
        ),
      );
    }

    if (!m.nestBoxDone) {
      final daysBefore = settings.nestBoxDaysBeforeKindling;
      // Rappel anticipé si configuré
      if (settings.nestBoxNoticeDays > 0) {
        out.add(
          ScheduledReminder(
            title:
                'Boîte à nid pour $female dans ${settings.nestBoxNoticeDays} jour${settings.nestBoxNoticeDays > 1 ? 's' : ''}',
            body:
                'Pensez à préparer la boîte à nid de $female (à installer le ${_dayMonth.format(nestBoxDay)}).',
            day: nestBoxDay.subtract(
              Duration(days: settings.nestBoxNoticeDays),
            ),
          ),
        );
      }

      out.add(
        ScheduledReminder(
          title: 'Boîte à nid pour $female',
          body:
              'La mise bas de $female aura lieu dans $daysBefore jour${daysBefore > 1 ? 's' : ''} : '
              'pensez à poser la boîte à nid.',
          day: nestBoxDay,
        ),
      );
    }

    // Rappel anticipé mise bas
    if (settings.kindlingNoticeDays > 0) {
      final noticeDays = settings.kindlingNoticeDays;
      out.add(
        ScheduledReminder(
          title:
              noticeDays == 1
                  ? 'Mise bas de $female demain'
                  : 'Mise bas de $female dans $noticeDays jours',
          body:
              noticeDays == 1
                  ? '$female devrait mettre bas demain (${_dayMonth.format(kindling)}). Vérifiez que la boîte à nid est prête.'
                  : '$female devrait mettre bas le ${_dayMonth.format(kindling)}. Préparez le clapier.',
          day: kindling.subtract(Duration(days: noticeDays)),
        ),
      );
    }

    // Le jour même de la mise bas
    out.add(
      ScheduledReminder(
        title: "Mise bas de $female aujourd'hui",
        body:
            "$female devrait mettre bas aujourd'hui. "
            'Enregistrez la portée dès que les lapereaux sont nés.',
        day: kindling,
      ),
    );
  }

  // Portées au nid : sevrage
  for (final l in provider.litters) {
    if (l.status == LitterStatus.weaned) continue;
    final mother = provider.getRabbitById(l.motherId)?.name ?? 'la mère';
    final kits = l.kitsRemaining;
    final kitsLabel = '$kits lapereau${kits > 1 ? 'x' : ''}';
    final weaning = _day(l.calculatedWeaningDateWith(settings.weaningDays));

    if (settings.weaningNoticeDays > 0) {
      final noticeDays = settings.weaningNoticeDays;
      out.add(
        ScheduledReminder(
          title:
              noticeDays == 1
                  ? 'Sevrage demain'
                  : 'Sevrage dans $noticeDays jours',
          body:
              'La portée de $mother ($kitsLabel) sera à sevrer le '
              '${_dayMonth.format(weaning)}.',
          day: weaning.subtract(Duration(days: noticeDays)),
        ),
      );
    }

    out.add(
      ScheduledReminder(
        title: 'Sevrage de la portée de $mother',
        body: "Les $kitsLabel de $mother sont prêts à être sevrés aujourd'hui.",
        day: weaning,
      ),
    );
  }

  // Soins prévus
  for (final c in provider.upcomingCares) {
    final who =
        c.rabbits.isEmpty
            ? 'tout le cheptel'
            : c.rabbits.map((r) => r.name).join(', ');
    final due = _day(c.dueDate);
    out
      ..add(
        ScheduledReminder(
          title: '${c.treatmentName} demain',
          body: 'Soin prévu demain pour $who.',
          day: due.subtract(const Duration(days: 1)),
        ),
      )
      ..add(
        ScheduledReminder(
          title: "${c.treatmentName} aujourd'hui",
          body: "Soin à faire aujourd'hui pour $who.",
          day: due,
        ),
      );
  }

  return out;
}


/// Fin d'abonnement payé : rappel 3 jours avant et le jour même.
List<ScheduledReminder> subscriptionNotifications(SubscriptionStatus? status) {
  final end = status?.periodEnd;
  if (status == null || !status.isPaid || end == null) return const [];
  final day = _day(end);
  final until = 'jusqu’au ${_dayMonth.format(day)}';
  return [
    ScheduledReminder(
      title: 'Abonnement ${status.planName} : fin dans 3 jours',
      body:
          'Votre formule est valable $until. Renouvelez-la depuis Profil > Abonnement '
          'pour continuer à ajouter des lapins.',
      day: day.subtract(const Duration(days: 3)),
    ),
    ScheduledReminder(
      title: 'Abonnement ${status.planName} : dernier jour',
      body:
          'Votre formule se termine aujourd’hui. Sans renouvellement, vous repassez '
          'à la formule gratuite (4 lapins).',
      day: day,
    ),
  ];
}
