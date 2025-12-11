enum TransactionType {
  income,
  expense,
  transfer,
}

enum TransactionStatus {
  active,    // Активная транзакция
  cancelled, // Отмененная транзакция
}

enum LocationType {
  cash,
  card,
  mobileWallet,
}

class TransactionLocation {
  final LocationType type;
  final String name;
  final String? id;
  final bool isTemporarilyVisible;

  TransactionLocation({
    required this.type,
    required this.name,
    this.id,
    this.isTemporarilyVisible = false,
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
      type = LocationType.cash;
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
  final TransactionLocation location;
  final TransactionLocation? transferTo;
  final TransactionStatus status; // ДОБАВЛЕНО

  Transaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.type,
    required this.date,
    required this.location,
    this.transferTo,
    this.status = TransactionStatus.active, // ДОБАВЛЕНО
  });

  bool get canBeCancelled {
    if (status == TransactionStatus.cancelled) return false;

    final now = DateTime.now();
    final hoursSinceTransaction = now.difference(date).inHours;

    // Можно отменить в течение 24 часов (1 дня) с момента создания
    return hoursSinceTransaction < 24;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'type': type.toString(),
      'date': date.toIso8601String(),
      'location': location.toJson(),
      'transferTo': transferTo?.toJson(),
      'status': status.toString(), // ДОБАВЛЕНО
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
      status: _parseStatus(json['status']), // ДОБАВЛЕНО
    );
  }

  static TransactionStatus _parseStatus(String? status) {
    if (status == 'TransactionStatus.cancelled') {
      return TransactionStatus.cancelled;
    }
    return TransactionStatus.active;
  }

  Transaction copyWith({
    String? id,
    String? description,
    double? amount,
    TransactionType? type,
    DateTime? date,
    TransactionLocation? location,
    TransactionLocation? transferTo,
    TransactionStatus? status,
  }) {
    return Transaction(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      date: date ?? this.date,
      location: location ?? this.location,
      transferTo: transferTo ?? this.transferTo,
      status: status ?? this.status,
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