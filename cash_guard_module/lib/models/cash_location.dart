class CashLocation {
  final String id;
  final String name;
  final double amount;
  final bool isHidden; // ДОБАВЛЕНО

  CashLocation({
    required this.id,
    required this.name,
    required this.amount,
    this.isHidden = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'isHidden': isHidden,
    };
  }

  factory CashLocation.fromJson(Map<String, dynamic> json) {
    return CashLocation(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      isHidden: json['isHidden'] ?? false,
    );
  }

  CashLocation copyWith({
    String? id,
    String? name,
    double? amount,
    bool? isHidden,
  }) {
    return CashLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      isHidden: isHidden ?? this.isHidden,
    );
  }
}