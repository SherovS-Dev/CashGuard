import 'debt.dart';
import 'cash_location.dart';
import 'bank_card.dart';
import 'mobile_wallet.dart';

class User {
  final String name;
  final List<CashLocation> cashLocations;
  final List<BankCard> bankCards;
  final List<MobileWallet> mobileWallets;

  User({
    required this.name,
    required this.cashLocations,
    required this.bankCards,
    required this.mobileWallets,
  });

  double get totalCash {
    return cashLocations
        .where((location) => !location.isHidden)
        .fold(0, (sum, location) => sum + location.amount);
  }

  double get totalBalance {
    double cardTotal = bankCards
        .where((card) => !card.isHidden)
        .fold(0, (sum, card) => sum + card.balance);
    double walletTotal = mobileWallets
        .where((wallet) => !wallet.isHidden)
        .fold(0, (sum, wallet) => sum + wallet.balance);
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
    List<CashLocation> cashLocations = [];

    if (json['cashLocations'] != null) {
      cashLocations = (json['cashLocations'] as List)
          .map((loc) => CashLocation.fromJson(loc))
          .toList();
    } else if (json['cashInHand'] != null) {
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

  double getTotalBorrowedDebts(List<Debt> debts) {
    return debts
        .where((d) => d.type == DebtType.borrowed && d.status != DebtStatus.fullyPaid)
        .fold(0, (sum, debt) => sum + debt.remainingWithInterest);
  }

  double getTotalLentDebts(List<Debt> debts) {
    return debts
        .where((d) => (d.type == DebtType.lent || d.type == DebtType.credit) &&
        d.status != DebtStatus.fullyPaid)
        .fold(0, (sum, debt) => sum + debt.remainingWithInterest);
  }

  double getNetBalance(List<Debt> debts) {
    return totalBalance + getTotalBorrowedDebts(debts) - getTotalLentDebts(debts);
  }

  double get cashInHand => totalCash;
}