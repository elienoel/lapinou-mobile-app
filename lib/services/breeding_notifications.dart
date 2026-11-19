import 'package:intl/intl.dart';
import '../models/litter.dart';
import '../providers/rabbit_provider.dart';
import 'reminder_notifications.dart';

final _dayMonth = DateFormat('dd/MM');

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Notifications de rappel de l'élevage, rédigées pour être comprises sans
/// ouvrir l'app, avec des rappels anticipés pour se préparer :
///
/// - palpation : le jour prévu (J12) ;
/// - boîte à nid : 3 jours avant la mise bas (J28), si elle n'est pas posée ;
/// - mise bas : la veille et le jour prévu ;
/// - sevrage : 3 jours avant et le jour prévu ;
/// - soins : la veille et le jour prévu.
///
/// Les étapes déjà faites ne sont pas rappelées ; les dates passées sont
/// écartées par [ReminderNotifications.plan].
List<ScheduledReminder> breedingNotifications(RabbitProvider provider) {
  final out = <ScheduledReminder>[];

  // Gestations en cours (sans mise bas enregistrée)
  for (final m in provider.matingsAwaitingKindling) {
    final female = provider.getRabbitById(m.femaleId)?.name ?? 'la femelle';
    final male = provider.getRabbitById(m.maleId)?.name ?? 'le mâle';
    final kindling = _day(m.expectedKindlingDate);

    if (!m.palpationDone) {
      out.add(
        ScheduledReminder(
          title: 'Palpation de $female',
          body:
              "C'est le moment de palper $female pour vérifier qu'elle est "
              'gestante (saillie avec $male le ${_dayMonth.format(m.matingDate)}).',
          day: m.palpationDate,
        ),
      );
    }
    if (!m.nestBoxDone) {
      out.add(
        ScheduledReminder(
          title: 'Boîte à nid pour $female',
          body:
              'La mise bas de $female aura lieu dans 3 jours : '
              'pensez à poser la boîte à nid.',
          day: kindling.subtract(const Duration(days: 3)),
        ),
      );
    }
    out
      ..add(
        ScheduledReminder(
          title: 'Mise bas de $female demain',
          body:
              '$female devrait mettre bas demain '
              '(${_dayMonth.format(kindling)}). Vérifiez que la boîte à nid est prête.',
          day: kindling.subtract(const Duration(days: 1)),
        ),
      )
      ..add(
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
    final weaning = _day(l.calculatedWeaningDate);
    out
      ..add(
        ScheduledReminder(
          title: 'Sevrage dans 3 jours',
          body:
              'La portée de $mother ($kitsLabel) sera à sevrer le '
              '${_dayMonth.format(weaning)}.',
          day: weaning.subtract(const Duration(days: 3)),
        ),
      )
      ..add(
        ScheduledReminder(
          title: 'Sevrage de la portée de $mother',
          body:
              "Les $kitsLabel de $mother sont prêts à être sevrés aujourd'hui.",
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
