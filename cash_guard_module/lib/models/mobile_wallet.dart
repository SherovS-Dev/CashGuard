class MobileWallet {
  final String name;
  final String phoneNumber;
  final double balance;
  final bool isHidden; // ДОБАВЛЕНО

  MobileWallet({
    required this.name,
    required this.phoneNumber,
    required this.balance,
    this.isHidden = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'balance': balance,
      'isHidden': isHidden,
    };
  }

  factory MobileWallet.fromJson(Map<String, dynamic> json) {
    return MobileWallet(
      name: json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      balance: (json['balance'] ?? 0).toDouble(),
      isHidden: json['isHidden'] ?? false,
    );
  }

  MobileWallet copyWith({
    String? name,
    String? phoneNumber,
    double? balance,
    bool? isHidden,
  }) {
    return MobileWallet(
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      balance: balance ?? this.balance,
      isHidden: isHidden ?? this.isHidden,
    );
  }
}