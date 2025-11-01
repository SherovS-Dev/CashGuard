enum TransactionType {
  income,
  expense,
  transfer, // Новый тип - перевод между счетами
}

enum LocationType {
  cash,
  card,
}

class TransactionLocation {
  final LocationType type;
  final String name; // Название (например: "Наличные в кошельке", "Сбербанк *1234")
  final String? id; // ID для карты (последние 4 цифры) или уникальный ID для наличных

  TransactionLocation({
    required this.type,
    required this.name,
    this.id,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString(),
      'name': name,
      'id': id,
    };
  }

  factory TransactionLocation.fromJson(Map<String, dynamic> json) {
    return TransactionLocation(
      type: json['type'] == 'LocationType.cash'
          ? LocationType.cash
          : LocationType.card,
      name: json['name'] ?? '',
      id: json['id'],
    );
  }
}

class Transaction {
  final String id;
  final String description;
  final double amount;
  final TransactionType type;
  final DateTime date;
  final String? category;
  final TransactionLocation location; // Источник для расходов/переводов, назначение для доходов
  final TransactionLocation? transferTo; // Куда переводим (только для переводов)

  Transaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.type,
    required this.date,
    this.category,
    required this.location,
    this.transferTo,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'type': type.toString(),
      'date': date.toIso8601String(),
      'category': category,
      'location': location.toJson(),
      'transferTo': transferTo?.toJson(),
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] ?? '',
      description: json['description'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      type: json['type'] == 'TransactionType.income'
          ? TransactionType.income
          : json['type'] == 'TransactionType.transfer'
          ? TransactionType.transfer
          : TransactionType.expense,
      date: DateTime.parse(json['date']),
      category: json['category'],
      location: TransactionLocation.fromJson(json['location']),
      transferTo: json['transferTo'] != null
          ? TransactionLocation.fromJson(json['transferTo'])
          : null,
    );
  }
}

class FinancialStats {
  final double totalIncome;
  final double totalExpenses;
  final double initialBalance;
  final List<Transaction> transactions;

  FinancialStats({
    required this.totalIncome,
    required this.totalExpenses,
    required this.initialBalance,
    required this.transactions,
  });

  double get currentBalance => initialBalance + totalIncome - totalExpenses;
  double get netChange => totalIncome - totalExpenses;
}