class MobileWallet {
  final String name;
  final String phoneNumber;
  final double balance;

  MobileWallet({
    required this.name,
    required this.phoneNumber,
    required this.balance,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'balance': balance,
    };
  }

  factory MobileWallet.fromJson(Map<String, dynamic> json) {
    return MobileWallet(
      name: json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      balance: (json['balance'] ?? 0).toDouble(),
    );
  }
}