enum DebtType {
  borrowed, // Я взял в долг (мне должны вернуть)
  lent, // Я дал в долг (я должен вернуть)
  credit, // Кредит от банка
}

enum DebtStatus {
  active, // Активный долг
  partiallyPaid, // Частично погашен
  fullyPaid, // Полностью погашен
}

class DebtPayment {
  final String id;
  final double amount;
  final DateTime date;
  final String? note;

  DebtPayment({
    required this.id,
    required this.amount,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory DebtPayment.fromJson(Map<String, dynamic> json) {
    return DebtPayment(
      id: json['id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      date: DateTime.parse(json['date']),
      note: json['note'],
    );
  }
}

class Debt {
  final String id;
  final String description; // Описание долга
  final String creditorDebtor; // Кредитор или должник (имя человека/банка)
  final double totalAmount; // Общая сумма долга
  final double interestRate; // Процентная ставка (0 если без процентов)
  final DebtType type;
  final DateTime startDate;
  final DateTime? dueDate; // Срок возврата (необязательно)
  final DebtStatus status;
  final List<DebtPayment> payments; // История платежей
  final String? notes; // Дополнительные заметки

  Debt({
    required this.id,
    required this.description,
    required this.creditorDebtor,
    required this.totalAmount,
    this.interestRate = 0,
    required this.type,
    required this.startDate,
    this.dueDate,
    required this.status,
    this.payments = const [],
    this.notes,
  });

  // Сумма уже выплаченная
  double get paidAmount {
    return payments.fold(0, (sum, payment) => sum + payment.amount);
  }

  // Остаток долга
  double get remainingAmount {
    return totalAmount - paidAmount;
  }

  // Общая сумма с процентами
  double get totalWithInterest {
    if (interestRate == 0) return totalAmount;
    return totalAmount * (1 + interestRate / 100);
  }

  // Остаток с учетом процентов
  double get remainingWithInterest {
    if (interestRate == 0) return remainingAmount;
    final totalWithInt = totalWithInterest;
    final paidPercentage = paidAmount / totalAmount;
    return totalWithInt * (1 - paidPercentage);
  }

  // Проверка просрочки
  bool get isOverdue {
    if (dueDate == null || status == DebtStatus.fullyPaid) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'creditorDebtor': creditorDebtor,
      'totalAmount': totalAmount,
      'interestRate': interestRate,
      'type': type.toString(),
      'startDate': startDate.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'status': status.toString(),
      'payments': payments.map((p) => p.toJson()).toList(),
      'notes': notes,
    };
  }

  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      id: json['id'] ?? '',
      description: json['description'] ?? '',
      creditorDebtor: json['creditorDebtor'] ?? '',
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      interestRate: (json['interestRate'] ?? 0).toDouble(),
      type: _parseDebtType(json['type']),
      startDate: DateTime.parse(json['startDate']),
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      status: _parseDebtStatus(json['status']),
      payments: (json['payments'] as List?)
          ?.map((p) => DebtPayment.fromJson(p))
          .toList() ??
          [],
      notes: json['notes'],
    );
  }

  static DebtType _parseDebtType(String? type) {
    switch (type) {
      case 'DebtType.borrowed':
        return DebtType.borrowed;
      case 'DebtType.lent':
        return DebtType.lent;
      case 'DebtType.credit':
        return DebtType.credit;
      default:
        return DebtType.borrowed;
    }
  }

  static DebtStatus _parseDebtStatus(String? status) {
    switch (status) {
      case 'DebtStatus.active':
        return DebtStatus.active;
      case 'DebtStatus.partiallyPaid':
        return DebtStatus.partiallyPaid;
      case 'DebtStatus.fullyPaid':
        return DebtStatus.fullyPaid;
      default:
        return DebtStatus.active;
    }
  }

  // Создание копии с обновленными полями
  Debt copyWith({
    String? id,
    String? description,
    String? creditorDebtor,
    double? totalAmount,
    double? interestRate,
    DebtType? type,
    DateTime? startDate,
    DateTime? dueDate,
    DebtStatus? status,
    List<DebtPayment>? payments,
    String? notes,
  }) {
    return Debt(
      id: id ?? this.id,
      description: description ?? this.description,
      creditorDebtor: creditorDebtor ?? this.creditorDebtor,
      totalAmount: totalAmount ?? this.totalAmount,
      interestRate: interestRate ?? this.interestRate,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      payments: payments ?? this.payments,
      notes: notes ?? this.notes,
    );
  }
}