enum TransactionType {
  income, // Vente lapereaux, reproducteurs, fumier/litière, etc.
  expense, // Alimentation, granulés, foin, matériel, vétérinaire
}

class FinanceTransaction {
  final String id;
  final TransactionType type;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final String? notes;

  const FinanceTransaction({
    required this.id,
    required this.type,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    this.notes,
  });

  bool get isIncome => type == TransactionType.income;

  factory FinanceTransaction.fromJson(Map<String, dynamic> json) {
    final tType =
        (json['transaction_type'] ?? '').toString().toLowerCase() == 'expense'
            ? TransactionType.expense
            : TransactionType.income;

    DateTime parsedDate = DateTime.now();
    if (json['date'] != null) {
      parsedDate = DateTime.tryParse(json['date'].toString()) ?? DateTime.now();
    }

    double parsedAmount = 0.0;
    if (json['amount'] != null) {
      parsedAmount = double.tryParse(json['amount'].toString()) ?? 0.0;
    }

    return FinanceTransaction(
      id: json['id'].toString(),
      type: tType,
      title: json['title'] ?? '',
      amount: parsedAmount,
      date: parsedDate,
      category: json['category'] ?? 'Général',
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transaction_type': type == TransactionType.income ? 'income' : 'expense',
      'title': title,
      'amount': amount,
      'date':
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'category': category,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }
}
