import 'package:intl/intl.dart';

/// « À l'instant », « il y a 5 min », « il y a 3h »… puis la date au-delà d'une semaine.
String timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return "À l'instant";
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
  if (diff.inDays < 7) return 'il y a ${diff.inDays}j';
  return DateFormat('dd/MM/yyyy', 'fr_FR').format(dt);
}

/// Heure d'un message dans la liste des discussions : « 14:32 », « Hier » ou « 03/09 ».
String chatListTime(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return DateFormat('HH:mm').format(dt);
  if (diff == 1) return 'Hier';
  return DateFormat('dd/MM').format(dt);
}

/// Séparateur de jour dans une conversation : « Aujourd'hui », « Hier » ou « jeudi 3 septembre ».
String chatDayLabel(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return "Aujourd'hui";
  if (diff == 1) return 'Hier';
  return DateFormat('EEEE d MMMM', 'fr_FR').format(dt);
}
