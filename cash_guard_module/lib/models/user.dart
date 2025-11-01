class User {
  final String name;
  final double cashInHand;
  final List<BankCard> bankCards;

  User({
    required this.name,
    required this.cashInHand,
    required this.bankCards,
  });

  double get totalBalance {
    double cardTotal = bankCards.fold(0, (sum, card) => sum + card.balance);
    return cashInHand + cardTotal;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'cashInHand': cashInHand,
      'bankCards': bankCards.map((card) => card.toJson()).toList(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      name: json['name'] ?? '',
      cashInHand: (json['cashInHand'] ?? 0).toDouble(),
      bankCards: (json['bankCards'] as List?)
          ?.map((card) => BankCard.fromJson(card))
          .toList() ??
          [],
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