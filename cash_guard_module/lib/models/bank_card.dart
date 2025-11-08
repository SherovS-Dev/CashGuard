class BankCard {
  final String cardName;
  final String cardNumber;
  final double balance;
  final String? bankName;
  final bool isHidden;

  BankCard({
    required this.cardName,
    required this.cardNumber,
    required this.balance,
    this.bankName,
    this.isHidden = false,
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
      'isHidden': isHidden,
    };
  }

  factory BankCard.fromJson(Map<String, dynamic> json) {
    return BankCard(
      cardName: json['cardName'] ?? '',
      cardNumber: json['cardNumber'] ?? '',
      balance: (json['balance'] ?? 0).toDouble(),
      bankName: json['bankName'],
      isHidden: json['isHidden'] ?? false,
    );
  }

  BankCard copyWith({
    String? cardName,
    String? cardNumber,
    double? balance,
    String? bankName,
    bool? isHidden,
  }) {
    return BankCard(
      cardName: cardName ?? this.cardName,
      cardNumber: cardNumber ?? this.cardNumber,
      balance: balance ?? this.balance,
      bankName: bankName ?? this.bankName,
      isHidden: isHidden ?? this.isHidden,
    );
  }
}