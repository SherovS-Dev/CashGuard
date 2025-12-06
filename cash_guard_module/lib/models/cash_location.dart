class CashLocation {
  final String id;
  final String name;
  final double amount;
  final bool isHidden;
  final int colorIndex; // Индекс цвета из палитры

  CashLocation({
    required this.id,
    required this.name,
    required this.amount,
    this.isHidden = false,
    this.colorIndex = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'isHidden': isHidden,
      'colorIndex': colorIndex,
    };
  }

  factory CashLocation.fromJson(Map<String, dynamic> json) {
    return CashLocation(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      isHidden: json['isHidden'] ?? false,
      colorIndex: json['colorIndex'] ?? 0,
    );
  }

  CashLocation copyWith({
    String? id,
    String? name,
    double? amount,
    bool? isHidden,
    int? colorIndex,
  }) {
    return CashLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      isHidden: isHidden ?? this.isHidden,
      colorIndex: colorIndex ?? this.colorIndex,
    );
  }
}