import 'debt.dart';

class User {
  final String name;
  final List<CashLocation> cashLocations; // Несколько мест хранения наличных
  final List<BankCard> bankCards;
  final List<MobileWallet> mobileWallets; // Мобильные кошельки

  User({
    required this.name,
    required this.cashLocations,
    required this.bankCards,
    required this.mobileWallets,
  });

  double get totalCash {
    return cashLocations.fold(0, (sum, location) => sum + location.amount);
  }

  double get totalBalance {
    double cardTotal = bankCards.fold(0, (sum, card) => sum + card.balance);
    double walletTotal = mobileWallets.fold(0, (sum, wallet) => sum + wallet.balance);
    return totalCash + cardTotal + walletTotal;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'cashLocations': cashLocations.map((loc) => loc.toJson()).toList(),
      'bankCards': bankCards.map((card) => card.toJson()).toList(),
      'mobileWallets': mobileWallets.map((wallet) => wallet.toJson()).toList(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    // Миграция со старого формата (если есть cashInHand)
    List<CashLocation> cashLocations = [];

    if (json['cashLocations'] != null) {
      cashLocations = (json['cashLocations'] as List)
          .map((loc) => CashLocation.fromJson(loc))
          .toList();
    } else if (json['cashInHand'] != null) {
      // Миграция со старого формата
      cashLocations = [
        CashLocation(
          id: 'main',
          name: 'Основное место',
          amount: (json['cashInHand'] ?? 0).toDouble(),
        ),
      ];
    }

    return User(
      name: json['name'] ?? '',
      cashLocations: cashLocations,
      bankCards: (json['bankCards'] as List?)
          ?.map((card) => BankCard.fromJson(card))
          .toList() ??
          [],
      mobileWallets: (json['mobileWallets'] as List?)
          ?.map((wallet) => MobileWallet.fromJson(wallet))
          .toList() ??
          [],
    );
  }

  // Общая сумма долгов (что мне должны)
  double getTotalBorrowedDebts(List<Debt> debts) {
    return debts
        .where((d) => d.type == DebtType.borrowed && d.status != DebtStatus.fullyPaid)
        .fold(0, (sum, debt) => sum + debt.remainingWithInterest);
  }

  // Общая сумма долгов (что я должен)
  double getTotalLentDebts(List<Debt> debts) {
    return debts
        .where((d) => (d.type == DebtType.lent || d.type == DebtType.credit) &&
        d.status != DebtStatus.fullyPaid)
        .fold(0, (sum, debt) => sum + debt.remainingWithInterest);
  }

  // Чистый баланс с учетом долгов
  double getNetBalance(List<Debt> debts) {
    return totalBalance + getTotalBorrowedDebts(debts) - getTotalLentDebts(debts);
  }

  // Для обратной совместимости
  double get cashInHand => totalCash;
}

class CashLocation {
  final String id;
  final String name; // Например: "В кошельке", "В сейфе", "Дома"
  final double amount;

  CashLocation({
    required this.id,
    required this.name,
    required this.amount,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
    };
  }

  factory CashLocation.fromJson(Map<String, dynamic> json) {
    return CashLocation(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
    );
  }
}

class BankCard {
  final String cardName;
  final String cardNumber;
  final double balance;
  final String? bankName;

  BankCard({
    required this.cardName,
    required this.cardNumber,
    required this.balance,
    this.bankName,
  });

  String get maskedCardNumber {
    if (cardNumber.length < 4) return cardNumber;
    return '**** **** **** ${cardNumber.substring(cardNumber.length - 4)}';
  }

  Map<String, dynamic> toJson() {
    return {
      'cardName': cardName,
      'cardNumber': cardNumber,
      'balance': balance,
      'bankName': bankName,
    };
  }

  factory BankCard.fromJson(Map<String, dynamic> json) {
    return BankCard(
      cardName: json['cardName'] ?? '',
      cardNumber: json['cardNumber'] ?? '',
      balance: (json['balance'] ?? 0).toDouble(),
      bankName: json['bankName'],
    );
  }
}

class MobileWallet {
  final String id;
  final String name; // Например: "Сбер Pay", "Тинькофф Pay"
  final String bankName;
  final double balance;

  MobileWallet({
    required this.id,
    required this.name,
    required this.bankName,
    required this.balance,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'bankName': bankName,
      'balance': balance,
    };
  }

  factory MobileWallet.fromJson(Map<String, dynamic> json) {
    return MobileWallet(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      bankName: json['bankName'] ?? '',
      balance: (json['balance'] ?? 0).toDouble(),
    );
  }
}