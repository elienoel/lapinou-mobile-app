import 'package:intl/intl.dart';

final _dayMonthYear = DateFormat('dd/MM/yyyy');

/// Date affichée partout dans l'app : 05/03/2026.
String formatDate(DateTime date) => _dayMonthYear.format(date);
