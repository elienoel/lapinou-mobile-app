import 'package:flutter_test/flutter_test.dart';
import 'package:clap_in/models/litter.dart';
import 'package:clap_in/providers/rabbit_provider.dart';
import 'package:clap_in/services/breeding_notifications.dart';
import 'package:clap_in/services/reminder_notifications.dart';

void main() {
  ScheduledReminder r(String title, DateTime day) =>
      ScheduledReminder(title: title, body: 'Noisette × Caramel', day: day);

  test('reminders ring at 8:00 on the due day, soonest first', () {
    final now = DateTime(2026, 11, 9, 7, 30);
    final plan = ReminderNotifications.plan([
      r('Mise bas à enregistrer', DateTime(2026, 11, 12, 15)),
      r('Palpation à faire', DateTime(2026, 11, 9)),
    ], now);

    expect(plan.map((e) => e.$2.title), [
      'Palpation à faire',
      'Mise bas à enregistrer',
    ]);
    expect(plan.first.$1, DateTime(2026, 11, 9, 8));
    expect(plan.last.$1, DateTime(2026, 11, 12, 8));
  });

  test('past and overdue reminders are not scheduled', () {
    final now = DateTime(2026, 11, 9, 10);
    final plan = ReminderNotifications.plan([
      r('Soin en retard', DateTime(2026, 11, 7)),
      r('Aujourd\'hui, 8 h déjà passées', DateTime(2026, 11, 9)),
      r('Demain', DateTime(2026, 11, 10)),
    ], now);

    expect(plan.map((e) => e.$2.title), ['Demain']);
  });

  test('scheduling stays under the iOS limit of 64 notifications', () {
    final now = DateTime(2026, 11, 9);
    final plan = ReminderNotifications.plan([
      for (var i = 1; i <= 80; i++)
        r('Soin $i', now.add(Duration(days: i))),
    ], now);

    expect(plan.length, 50);
    expect(plan.first.$2.title, 'Soin 1');
  });

  test('without init (tests, web) scheduling does nothing', () async {
    ReminderNotifications.instance.schedule([
      r('Palpation à faire', DateTime.now().add(const Duration(days: 2))),
    ]);
    await ReminderNotifications.instance.clear();
  });

  group('breeding notifications', () {
    DateTime day(int fromToday) {
      final n = DateTime.now();
      return DateTime(n.year, n.month, n.day + fromToday);
    }

    ScheduledReminder find(List<ScheduledReminder> all, String title) =>
        all.firstWhere((r) => r.title == title);

    test('a pregnancy is announced step by step, ahead of time', () {
      // mat-2 : Luna × Goliath, saillie il y a 8 jours, palpation pas faite
      final provider = RabbitProvider()..seedForTesting();
      final all = breedingNotifications(provider);

      final palpation = find(all, 'Palpation de Luna');
      expect(_day(palpation.day), day(4)); // J12
      expect(palpation.body, contains('Goliath'));

      final nest = find(all, 'Boîte à nid pour Luna');
      expect(_day(nest.day), day(20)); // 3 jours avant la mise bas (J31)
      expect(
        nest.body,
        'La mise bas de Luna aura lieu dans 3 jours : pensez à poser la boîte à nid.',
      );

      expect(_day(find(all, 'Mise bas de Luna demain').day), day(22));
      expect(_day(find(all, "Mise bas de Luna aujourd'hui").day), day(23));
    });

    test('done steps are not reminded', () {
      final provider = RabbitProvider()..seedForTesting();
      final m = provider.getMatingById('mat-2')!;
      provider.setMatingsForTesting([
        m.copyWith(palpationDoneAt: day(0), nestBoxDoneAt: day(0)),
      ]);
      final titles = breedingNotifications(provider).map((r) => r.title);
      expect(titles, isNot(contains('Palpation de Luna')));
      expect(titles, isNot(contains('Boîte à nid pour Luna')));
      expect(titles, contains("Mise bas de Luna aujourd'hui"));
    });

    test('litters at the nest are reminded before weaning', () {
      final provider = RabbitProvider()..seedForTesting();
      provider.setLittersForTesting([
        Litter(
          id: 'l',
          motherId: 'p-f-1',
          birthDate: day(-40),
          bornAlive: 6,
        ),
      ]);
      final all = breedingNotifications(provider);
      final soon = find(all, 'Sevrage dans 3 jours');
      expect(_day(soon.day), day(2)); // sevrage à 45 jours
      expect(soon.body, contains('Bella (6 lapereaux)'));
      expect(_day(find(all, 'Sevrage de la portée de Bella').day), day(5));
    });
  });
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
