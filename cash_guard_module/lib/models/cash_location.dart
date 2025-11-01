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