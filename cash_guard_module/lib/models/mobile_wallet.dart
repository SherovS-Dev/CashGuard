class MobileWallet {
  final String name;
  final String phoneNumber;
  final double balance;
  final bool isHidden;
  final int colorIndex; // Индекс цвета из палитры

  MobileWallet({
    required this.name,
    required this.phoneNumber,
    required this.balance,
    this.isHidden = false,
    this.colorIndex = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'balance': balance,
      'isHidden': isHidden,
      'colorIndex': colorIndex,
    };
  }

  factory MobileWallet.fromJson(Map<String, dynamic> json) {
    return MobileWallet(
      name: json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      balance: (json['balance'] ?? 0).toDouble(),
      isHidden: json['isHidden'] ?? false,
      colorIndex: json['colorIndex'] ?? 0,
    );
  }

  MobileWallet copyWith({
    String? name,
    String? phoneNumber,
    double? balance,
    bool? isHidden,
    int? colorIndex,
  }) {
    return MobileWallet(
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      balance: balance ?? this.balance,
      isHidden: isHidden ?? this.isHidden,
      colorIndex: colorIndex ?? this.colorIndex,
    );
  }
}