import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/finance_transaction.dart';

const List<String> _defaultIncomeCategories = [
  'Vente reproducteurs',
  'Vente lapereaux',
  'Vente fumier / litière',
  'Autre revenu',
];

const List<String> _defaultExpenseCategories = [
  'Alimentation',
  'Vétérinaire / Soins',
  'Matériel',
  'Litière',
  'Autre dépense',
];

const _prefsKeyIncome = 'categories_income';
const _prefsKeyExpense = 'categories_expense';

/// Catégories de dépenses/revenus utilisées dans le formulaire de transaction.
///
/// Propres à l'appareil (persistées en local via SharedPreferences) : le backend
/// stocke la catégorie de chaque transaction en texte libre, il n'y a pas de table
/// de catégories côté serveur à synchroniser.
class CategoryProvider extends ChangeNotifier {
  List<String> _income = List.of(_defaultIncomeCategories);
  List<String> _expense = List.of(_defaultExpenseCategories);
  bool _loaded = false;

  List<String> get incomeCategories => List.unmodifiable(_income);
  List<String> get expenseCategories => List.unmodifiable(_expense);

  List<String> categoriesFor(TransactionType type) =>
      type == TransactionType.income ? incomeCategories : expenseCategories;

  CategoryProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawIncome = prefs.getString(_prefsKeyIncome);
    final rawExpense = prefs.getString(_prefsKeyExpense);
    if (rawIncome != null) {
      _income = List<String>.from(jsonDecode(rawIncome));
    }
    if (rawExpense != null) {
      _expense = List<String>.from(jsonDecode(rawExpense));
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist(TransactionType type) async {
    final prefs = await SharedPreferences.getInstance();
    final key =
        type == TransactionType.income ? _prefsKeyIncome : _prefsKeyExpense;
    final list = type == TransactionType.income ? _income : _expense;
    await prefs.setString(key, jsonEncode(list));
  }

  /// Ajoute une catégorie si elle n'existe pas déjà (comparaison insensible à la
  /// casse). Renvoie le libellé effectivement utilisé (existant ou nouveau).
  Future<String> addCategory(TransactionType type, String label) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return trimmed;
    final list = type == TransactionType.income ? _income : _expense;
    final existing = list.firstWhere(
      (c) => c.toLowerCase() == trimmed.toLowerCase(),
      orElse: () => '',
    );
    if (existing.isNotEmpty) return existing;
    list.add(trimmed);
    notifyListeners();
    await _persist(type);
    return trimmed;
  }

  Future<void> removeCategory(TransactionType type, String label) async {
    final list = type == TransactionType.income ? _income : _expense;
    list.remove(label);
    notifyListeners();
    await _persist(type);
  }

  bool get isLoaded => _loaded;
}
