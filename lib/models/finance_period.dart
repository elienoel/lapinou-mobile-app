import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'finance_transaction.dart';

/// Types de période pour filtrer et totaliser les finances.
enum FinancePeriodKind { all, month, year, custom }

/// Période d'analyse des finances : un mois (le filtre affiché sur la page),
/// une année, une plage libre, ou tout l'historique. Les bornes sont des jours
/// entiers, incluses.
class FinancePeriod {
  final FinancePeriodKind kind;

  /// Premier jour du mois ou de l'année ([FinancePeriodKind.month] / [FinancePeriodKind.year])
  final DateTime? start;

  /// Bornes choisies par l'utilisateur (uniquement pour [FinancePeriodKind.custom])
  final DateTimeRange? custom;

  const FinancePeriod._(this.kind, {this.start, this.custom});

  static const all = FinancePeriod._(FinancePeriodKind.all);

  factory FinancePeriod.month(int year, int month) =>
      FinancePeriod._(FinancePeriodKind.month, start: DateTime(year, month));

  /// Le mois en cours.
  factory FinancePeriod.thisMonth([DateTime? now]) {
    final d = now ?? DateTime.now();
    return FinancePeriod.month(d.year, d.month);
  }

  factory FinancePeriod.year(int year) =>
      FinancePeriod._(FinancePeriodKind.year, start: DateTime(year));

  factory FinancePeriod.custom(DateTimeRange range) => FinancePeriod._(
    FinancePeriodKind.custom,
    custom: DateTimeRange(start: _day(range.start), end: _day(range.end)),
  );

  /// Les [count] derniers mois, du mois en cours au plus ancien.
  static List<FinancePeriod> recentMonths(int count, [DateTime? now]) {
    final d = now ?? DateTime.now();
    return [
      for (var i = 0; i < count; i++) FinancePeriod.month(d.year, d.month - i),
    ];
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Bornes de la période ; null quand elle couvre tout l'historique.
  DateTimeRange? range() {
    switch (kind) {
      case FinancePeriodKind.all:
        return null;
      case FinancePeriodKind.month:
        return DateTimeRange(
          start: start!,
          end: DateTime(start!.year, start!.month + 1, 0),
        );
      case FinancePeriodKind.year:
        return DateTimeRange(start: start!, end: DateTime(start!.year, 12, 31));
      case FinancePeriodKind.custom:
        return custom;
    }
  }

  bool contains(DateTime date) {
    final r = range();
    if (r == null) return true;
    final d = _day(date);
    return !d.isBefore(r.start) && !d.isAfter(r.end);
  }

  /// « Novembre 2026 », « Année 2026 », « Du 01/01/2026 au 15/08/2026 », « Tout ».
  String get label {
    switch (kind) {
      case FinancePeriodKind.all:
        return 'Tout';
      case FinancePeriodKind.month:
        final m = DateFormat('MMMM yyyy', 'fr_FR').format(start!);
        return '${m[0].toUpperCase()}${m.substring(1)}';
      case FinancePeriodKind.year:
        return 'Année ${start!.year}';
      case FinancePeriodKind.custom:
        return describe();
    }
  }

  /// « Du 01/09/2026 au 30/09/2026 », ou « Depuis le début » pour tout l'historique.
  String describe() {
    final r = range();
    if (r == null) return 'Depuis le début';
    final f = DateFormat('dd/MM/yyyy');
    return r.start == r.end
        ? 'Le ${f.format(r.start)}'
        : 'Du ${f.format(r.start)} au ${f.format(r.end)}';
  }

  @override
  bool operator ==(Object other) =>
      other is FinancePeriod &&
      other.kind == kind &&
      other.start == start &&
      other.custom == custom;

  @override
  int get hashCode => Object.hash(kind, start, custom);
}

/// Totaux d'une liste de transactions.
class FinanceTotals {
  final double income;
  final double expense;
  final int incomeCount;
  final int expenseCount;

  const FinanceTotals({
    required this.income,
    required this.expense,
    required this.incomeCount,
    required this.expenseCount,
  });

  double get balance => income - expense;

  factory FinanceTotals.of(Iterable<FinanceTransaction> transactions) {
    double income = 0, expense = 0;
    int incomeCount = 0, expenseCount = 0;
    for (final t in transactions) {
      if (t.isIncome) {
        income += t.amount;
        incomeCount++;
      } else {
        expense += t.amount;
        expenseCount++;
      }
    }
    return FinanceTotals(
      income: income,
      expense: expense,
      incomeCount: incomeCount,
      expenseCount: expenseCount,
    );
  }
}
