class BankCard {
  final String cardName;
  final String cardNumber;
  final double balance;
  final String? bankName;
  final bool isHidden;
  final int colorIndex; // Индекс цвета из палитры

  BankCard({
    required this.cardName,
    required this.cardNumber,
    required this.balance,
    this.bankName,
    this.isHidden = false,
    this.colorIndex = 0,
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
      'colorIndex': colorIndex,
    };
  }

  factory BankCard.fromJson(Map<String, dynamic> json) {
    return BankCard(
      cardName: json['cardName'] ?? '',
      cardNumber: json['cardNumber'] ?? '',
      balance: (json['balance'] ?? 0).toDouble(),
      bankName: json['bankName'],
      isHidden: json['isHidden'] ?? false,
      colorIndex: json['colorIndex'] ?? 0,
    );
  }

  BankCard copyWith({
    String? cardName,
    String? cardNumber,
    double? balance,
    String? bankName,
    bool? isHidden,
    int? colorIndex,
  }) {
    return BankCard(
      cardName: cardName ?? this.cardName,
      cardNumber: cardNumber ?? this.cardNumber,
      balance: balance ?? this.balance,
      bankName: bankName ?? this.bankName,
      isHidden: isHidden ?? this.isHidden,
      colorIndex: colorIndex ?? this.colorIndex,
    );
  }
}