import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'finance_transaction.dart';

/// Périodes proposées pour filtrer et totaliser les finances.
enum FinancePeriodKind { all, thisMonth, lastMonth, thisYear, custom }

/// Période d'analyse des finances. Les bornes sont des jours entiers, incluses.
class FinancePeriod {
  final FinancePeriodKind kind;

  /// Bornes choisies par l'utilisateur (uniquement pour [FinancePeriodKind.custom])
  final DateTimeRange? custom;

  const FinancePeriod(this.kind, {this.custom});

  static const all = FinancePeriod(FinancePeriodKind.all);

  factory FinancePeriod.custom(DateTimeRange range) => FinancePeriod(
    FinancePeriodKind.custom,
    custom: DateTimeRange(start: _day(range.start), end: _day(range.end)),
  );

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Bornes de la période ; null quand elle couvre tout l'historique.
  DateTimeRange? range([DateTime? now]) {
    final today = _day(now ?? DateTime.now());
    switch (kind) {
      case FinancePeriodKind.all:
        return null;
      case FinancePeriodKind.thisMonth:
        return DateTimeRange(
          start: DateTime(today.year, today.month, 1),
          end: DateTime(today.year, today.month + 1, 0),
        );
      case FinancePeriodKind.lastMonth:
        return DateTimeRange(
          start: DateTime(today.year, today.month - 1, 1),
          end: DateTime(today.year, today.month, 0),
        );
      case FinancePeriodKind.thisYear:
        return DateTimeRange(
          start: DateTime(today.year, 1, 1),
          end: DateTime(today.year, 12, 31),
        );
      case FinancePeriodKind.custom:
        return custom;
    }
  }

  bool contains(DateTime date, [DateTime? now]) {
    final r = range(now);
    if (r == null) return true;
    final d = _day(date);
    return !d.isBefore(r.start) && !d.isAfter(r.end);
  }

  String get label {
    switch (kind) {
      case FinancePeriodKind.all:
        return 'Tout';
      case FinancePeriodKind.thisMonth:
        return 'Ce mois';
      case FinancePeriodKind.lastMonth:
        return 'Mois dernier';
      case FinancePeriodKind.thisYear:
        return 'Cette année';
      case FinancePeriodKind.custom:
        return 'Personnalisé';
    }
  }

  /// « Du 01/09/2026 au 30/09/2026 », ou « Depuis le début » pour tout l'historique.
  String describe([DateTime? now]) {
    final r = range(now);
    if (r == null) return 'Depuis le début';
    final f = DateFormat('dd/MM/yyyy');
    return r.start == r.end
        ? 'Le ${f.format(r.start)}'
        : 'Du ${f.format(r.start)} au ${f.format(r.end)}';
  }

  @override
  bool operator ==(Object other) =>
      other is FinancePeriod && other.kind == kind && other.custom == custom;

  @override
  int get hashCode => Object.hash(kind, custom);
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
