enum TransactionType {
  income,
  expense,
  transfer, // Новый тип - перевод между счетами
}

enum LocationType {
  cash,
  card,
  mobileWallet, // Мобильный кошелек банка
}

class TransactionLocation {
  final LocationType type;
  final String name; // Название (например: "Наличные в кошельке", "Сбербанк *1234", "Сбер Pay")
  final String? id; // ID для карты (последние 4 цифры) или уникальный ID для наличных/кошельков

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
    LocationType type;
    final typeString = json['type'] as String;

    if (typeString == 'LocationType.cash') {
      type = LocationType.cash;
    } else if (typeString == 'LocationType.card') {
      type = LocationType.card;
    } else if (typeString == 'LocationType.mobileWallet') {
      type = LocationType.mobileWallet;
    } else {
      type = LocationType.cash; // fallback
    }

    return TransactionLocation(
      type: type,
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
  final TransactionLocation location; // Источник для расходов/переводов, назначение для доходов
  final TransactionLocation? transferTo; // Куда переводим (только для переводов)

  Transaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.type,
    required this.date,
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