import 'package:flutter/material.dart';
import '../models/bank_card.dart';
import '../models/cash_location.dart';
import '../models/mobile_wallet.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import '../services/secure_storage_service.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _storageService = SecureStorageService();
  final PageController _pageController = PageController(initialPage: 0);

  List<Transaction> _transactions = [];
  double _initialBalance = 0;
  bool _isLoading = true;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _cleanOldTransactions();
    await _generateMonthlyStats();

    final transactions = await _storageService.getTransactions();
    final initialBalance = await _storageService.getInitialBalance();

    setState(() {
      _transactions = transactions..sort((a, b) => b.date.compareTo(a.date));
      _initialBalance = initialBalance;
      _isLoading = false;
    });
  }

  Future<void> _cleanOldTransactions() async {
    final transactions = await _storageService.getTransactions();
    final now = DateTime.now();
    final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day - 1);

    final filteredTransactions = transactions.where((t) {
      return t.date.isAfter(threeMonthsAgo);
    }).toList();

    if (filteredTransactions.length != transactions.length) {
      await _storageService.saveTransactions(filteredTransactions);
    }
  }

  Future<void> _generateMonthlyStats() async {
    final now = DateTime.now();

    if (now.day == 1) {
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      await _createMonthlySnapshot(lastMonth);
    }

    if (now.month == 1 && now.day == 1) {
      final lastYear = DateTime(now.year - 1, 1, 1);
      await _createYearlySnapshot(lastYear);
    }
  }

  Future<void> _createMonthlySnapshot(DateTime month) async {
    final snapshots = await _storageService.getMonthlySnapshots();
    final snapshotKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';

    if (snapshots.containsKey(snapshotKey)) return;

    final transactions = await _storageService.getTransactions();
    final debts = await _storageService.getDebts();
    final user = await _storageService.getUserData();

    final monthTransactions = transactions.where((t) {
      return t.date.year == month.year &&
          t.date.month == month.month &&
          t.status == TransactionStatus.active;
    }).toList();

    final income = monthTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);

    final expenses = monthTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    final prevMonth = DateTime(month.year, month.month - 1, 1);
    final prevSnapshotKey = '${prevMonth.year}-${prevMonth.month.toString().padLeft(2, '0')}';
    final prevSnapshot = snapshots[prevSnapshotKey];

    final startBorrowedDebts = prevSnapshot?['endBorrowedDebts'] ??
        (user?.getTotalBorrowedDebts(debts) ?? 0);
    final startLentDebts = prevSnapshot?['endLentDebts'] ??
        (user?.getTotalLentDebts(debts) ?? 0);

    final endBorrowedDebts = user?.getTotalBorrowedDebts(debts) ?? 0;
    final endLentDebts = user?.getTotalLentDebts(debts) ?? 0;

    final snapshot = {
      'month': month.toIso8601String(),
      'startBalance': prevSnapshot?['endBalance'] ?? _initialBalance,
      'endBalance': user?.totalBalance ?? 0,
      'income': income,
      'expenses': expenses,
      'transactionCount': monthTransactions.length,
      'startBorrowedDebts': startBorrowedDebts,
      'endBorrowedDebts': endBorrowedDebts,
      'startLentDebts': startLentDebts,
      'endLentDebts': endLentDebts,
    };

    await _storageService.saveMonthlySnapshot(snapshotKey, snapshot);
  }

  Future<void> _createYearlySnapshot(DateTime year) async {
    final snapshots = await _storageService.getYearlySnapshots();
    final snapshotKey = year.year.toString();

    if (snapshots.containsKey(snapshotKey)) return;

    final transactions = await _storageService.getTransactions();
    final debts = await _storageService.getDebts();
    final user = await _storageService.getUserData();

    final yearTransactions = transactions.where((t) {
      return t.date.year == year.year &&
          t.status == TransactionStatus.active;
    }).toList();

    final income = yearTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);

    final expenses = yearTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    final prevYear = DateTime(year.year - 1, 1, 1);
    final prevSnapshotKey = prevYear.year.toString();
    final prevSnapshot = snapshots[prevSnapshotKey];

    final startBorrowedDebts = prevSnapshot?['endBorrowedDebts'] ??
        (user?.getTotalBorrowedDebts(debts) ?? 0);
    final startLentDebts = prevSnapshot?['endLentDebts'] ??
        (user?.getTotalLentDebts(debts) ?? 0);

    final endBorrowedDebts = user?.getTotalBorrowedDebts(debts) ?? 0;
    final endLentDebts = user?.getTotalLentDebts(debts) ?? 0;

    final snapshot = {
      'year': year.toIso8601String(),
      'startBalance': prevSnapshot?['endBalance'] ?? _initialBalance,
      'endBalance': user?.totalBalance ?? 0,
      'income': income,
      'expenses': expenses,
      'transactionCount': yearTransactions.length,
      'startBorrowedDebts': startBorrowedDebts,
      'endBorrowedDebts': endBorrowedDebts,
      'startLentDebts': startLentDebts,
      'endLentDebts': endLentDebts,
    };

    await _storageService.saveYearlySnapshot(snapshotKey, snapshot);
  }

  double get _totalIncome {
    return _transactions
        .where((t) => t.type == TransactionType.income && t.status == TransactionStatus.active)
        .fold(0, (sum, t) => sum + t.amount);
  }

  double get _totalExpenses {
    return _transactions
        .where((t) => t.type == TransactionType.expense && t.status == TransactionStatus.active)
        .fold(0, (sum, t) => sum + t.amount);
  }

  double get _currentBalance {
    return _initialBalance + _totalIncome - _totalExpenses;
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} ₽';
  }

  Future<void> _cancelTransaction(Transaction transaction) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            const Expanded(child: Text('Отменить транзакцию?')), // ИСПРАВЛЕНО
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Вы уверены, что хотите отменить "${transaction.description}"?',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Баланс будет восстановлен, транзакция останется в истории как отмененная',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Назад'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Отменить'),
          ),
        ],
      ),
    );

    if (shouldCancel == true) {
      final user = await _storageService.getUserData();
      if (user != null) {
        User updatedUser = user;

        if (transaction.type == TransactionType.transfer) {
          updatedUser = _updateBalance(updatedUser, transaction.location, transaction.amount);
          updatedUser = _updateBalance(updatedUser, transaction.transferTo!, -transaction.amount);
        } else {
          final amountChange = transaction.type == TransactionType.income
              ? -transaction.amount
              : transaction.amount;

          updatedUser = _updateBalance(updatedUser, transaction.location, amountChange);
        }

        await _storageService.saveUserData(updatedUser);
      }

      await _storageService.cancelTransaction(transaction.id);

      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Транзакция отменена'),
              ],
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    if (transaction.status == TransactionStatus.cancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Отмененные транзакции нельзя удалить'),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red.shade700),
            const SizedBox(width: 12),
            const Expanded(child: Text('Удалить транзакцию?')), // ИСПРАВЛЕНО
          ],
        ),
        content: Text(
          transaction.type == TransactionType.transfer
              ? 'Вы уверены, что хотите удалить "${transaction.description}"?\n\nБаланс будет восстановлен.'
              : 'Вы уверены, что хотите удалить "${transaction.description}"?\n\nБаланс в ${transaction.location.name} будет обновлен.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      final user = await _storageService.getUserData();
      if (user != null) {
        User updatedUser = user;

        if (transaction.type == TransactionType.transfer) {
          updatedUser = _updateBalance(updatedUser, transaction.location, transaction.amount);
          updatedUser = _updateBalance(updatedUser, transaction.transferTo!, -transaction.amount);
        } else {
          final amountChange = transaction.type == TransactionType.income
              ? -transaction.amount
              : transaction.amount;

          updatedUser = _updateBalance(updatedUser, transaction.location, amountChange);
        }

        await _storageService.saveUserData(updatedUser);
      }

      await _storageService.deleteTransaction(transaction.id);
      _loadData();
    }
  }

  User _updateBalance(User user, TransactionLocation location, double amountChange) {
    switch (location.type) {
      case LocationType.cash:
        final updatedCashLocations = user.cashLocations.map((loc) {
          if (loc.id == location.id) {
            return CashLocation(
              id: loc.id,
              name: loc.name,
              amount: loc.amount + amountChange,
              isHidden: loc.isHidden,
            );
          }
          return loc;
        }).toList();

        return User(
          name: user.name,
          cashLocations: updatedCashLocations,
          bankCards: user.bankCards,
          mobileWallets: user.mobileWallets,
        );

      case LocationType.card:
        final parts = location.id?.split('|');
        if (parts == null || parts.length != 2) {
          return user;
        }

        final cardName = parts[0];
        final last4Digits = parts[1];

        final updatedCards = user.bankCards.map((card) {
          final cardLast4 = card.cardNumber.substring(card.cardNumber.length - 4);
          if (card.cardName == cardName && cardLast4 == last4Digits) {
            return BankCard(
              cardName: card.cardName,
              cardNumber: card.cardNumber,
              balance: card.balance + amountChange,
              bankName: card.bankName,
              isHidden: card.isHidden,
            );
          }
          return card;
        }).toList();

        return User(
          name: user.name,
          cashLocations: user.cashLocations,
          bankCards: updatedCards,
          mobileWallets: user.mobileWallets,
        );

      case LocationType.mobileWallet:
        final updatedWallets = user.mobileWallets.map((wallet) {
          if (wallet.name == location.name) {
            return MobileWallet(
              name: wallet.name,
              phoneNumber: wallet.phoneNumber,
              balance: wallet.balance + amountChange,
              isHidden: wallet.isHidden,
            );
          }
          return wallet;
        }).toList();

        return User(
          name: user.name,
          cashLocations: user.cashLocations,
          bankCards: user.bankCards,
          mobileWallets: updatedWallets,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.deepPurple.shade50,
                Colors.white,
              ],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (page) {
          setState(() {
            _currentPage = page;
          });
        },
        children: [
          // ИЗМЕНЕНО: Страница текущих транзакций (слева)
          _buildCurrentTransactionsPage(),

          // ИЗМЕНЕНО: Страница статистики (справа)
          _StatisticsPage(
            storageService: _storageService,
            formatCurrency: _formatCurrency,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTransactionsPage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.deepPurple.shade50,
            Colors.white,
          ],
        ),
      ),
      child: CustomScrollView(
        slivers: [
          // ИСПРАВЛЕНО: App Bar с правильными размерами
          SliverAppBar(
            expandedHeight: 220, // УВЕЛИЧЕНО
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.deepPurple.shade400,
                      Colors.deepPurple.shade700,
                      Colors.indigo.shade800,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // ИСПРАВЛЕНО: Компактный заголовок
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Транзакции',
                                style: TextStyle(
                                  fontSize: 24, // УМЕНЬШЕНО
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Статистика',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_rounded, // ИЗМЕНЕНО
                                    color: Colors.white.withValues(alpha: 0.9),
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                title: 'Доходы',
                                amount: _formatCurrency(_totalIncome),
                                icon: Icons.arrow_downward_rounded,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                title: 'Расходы',
                                amount: _formatCurrency(_totalExpenses),
                                icon: Icons.arrow_upward_rounded,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, color: Colors.deepPurple.shade600),
                  const SizedBox(width: 8),
                  const Expanded( // ИСПРАВЛЕНО
                    child: Text(
                      'История (3 месяца)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_transactions.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Нет транзакций',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Добавьте первую транзакцию',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final transaction = _transactions[index];
                    if (transaction.status == TransactionStatus.cancelled) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TransactionCard(
                          transaction: transaction,
                          onCancel: null,
                          onDelete: null,
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Dismissible(
                        key: Key(transaction.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async {
                          await _deleteTransaction(transaction);
                          return false;
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.delete_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        child: _TransactionCard(
                          transaction: transaction,
                          onCancel: transaction.canBeCancelled
                              ? () => _cancelTransaction(transaction)
                              : null,
                          onDelete: () => _deleteTransaction(transaction),
                        ),
                      ),
                    );
                  },
                  childCount: _transactions.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }
}

class _StatisticsPage extends StatefulWidget {
  final SecureStorageService storageService;
  final String Function(double) formatCurrency;

  const _StatisticsPage({
    required this.storageService,
    required this.formatCurrency,
  });

  @override
  State<_StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<_StatisticsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _monthlySnapshots = {};
  Map<String, dynamic> _yearlySnapshots = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSnapshots();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSnapshots() async {
    final monthly = await widget.storageService.getMonthlySnapshots();
    final yearly = await widget.storageService.getYearlySnapshots();

    setState(() {
      _monthlySnapshots = monthly;
      _yearlySnapshots = yearly;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple.shade50,
              Colors.white,
            ],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.deepPurple.shade50,
            Colors.white,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.deepPurple.shade400,
                    Colors.deepPurple.shade700,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Статистика',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Транзакции',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.swipe_right_rounded,
                              color: Colors.white.withValues(alpha: 0.9),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    tabs: const [
                      Tab(text: 'По месяцам'),
                      Tab(text: 'По годам'),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMonthlyStats(),
                  _buildYearlyStats(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyStats() {
    if (_monthlySnapshots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 64,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'Нет месячной статистики',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Статистика создается автоматически\nв начале каждого месяца',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sortedKeys = _monthlySnapshots.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final key = sortedKeys[index];
        final snapshot = _monthlySnapshots[key] as Map<String, dynamic>;
        final date = DateTime.parse(snapshot['month']);

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _SnapshotCard(
            title: '${_getMonthName(date.month)} ${date.year}',
            snapshot: snapshot,
            formatCurrency: widget.formatCurrency,
            isMonthly: true,
          ),
        );
      },
    );
  }

  Widget _buildYearlyStats() {
    if (_yearlySnapshots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 64,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'Нет годовой статистики',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Статистика создается автоматически\n1 января каждого года',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sortedKeys = _yearlySnapshots.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final key = sortedKeys[index];
        final snapshot = _yearlySnapshots[key] as Map<String, dynamic>;
        final date = DateTime.parse(snapshot['year']);

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _SnapshotCard(
            title: '${date.year} год',
            snapshot: snapshot,
            formatCurrency: widget.formatCurrency,
            isMonthly: false,
          ),
        );
      },
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];
    return months[month - 1];
  }
}

class _SnapshotCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> snapshot;
  final String Function(double) formatCurrency;
  final bool isMonthly;

  const _SnapshotCard({
    required this.title,
    required this.snapshot,
    required this.formatCurrency,
    required this.isMonthly,
  });

  @override
  Widget build(BuildContext context) {
    final startBalance = (snapshot['startBalance'] ?? 0).toDouble();
    final endBalance = (snapshot['endBalance'] ?? 0).toDouble();
    final income = (snapshot['income'] ?? 0).toDouble();
    final expenses = (snapshot['expenses'] ?? 0).toDouble();
    final transactionCount = snapshot['transactionCount'] ?? 0;

    final startBorrowedDebts = (snapshot['startBorrowedDebts'] ?? 0).toDouble();
    final endBorrowedDebts = (snapshot['endBorrowedDebts'] ?? 0).toDouble();
    final startLentDebts = (snapshot['startLentDebts'] ?? 0).toDouble();
    final endLentDebts = (snapshot['endLentDebts'] ?? 0).toDouble();

    final balanceChange = endBalance - startBalance;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.shade400,
                  Colors.deepPurple.shade600,
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$transactionCount ${isMonthly ? "транзакций" : "транзакций за год"}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Баланс
                _InfoRow(
                  label: 'Баланс в начале',
                  value: formatCurrency(startBalance),
                  valueColor: Colors.grey.shade700,
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Баланс в конце',
                  value: formatCurrency(endBalance),
                  valueColor: Colors.deepPurple.shade700,
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Изменение',
                  value: '${balanceChange >= 0 ? "+" : ""}${formatCurrency(balanceChange)}',
                  valueColor: balanceChange >= 0 ? Colors.green : Colors.red,
                ),

                const Divider(height: 32),

                // Доходы и расходы
                Row(
                  children: [
                    Expanded(
                      child: _MiniStatCard(
                        label: 'Доходы',
                        value: formatCurrency(income),
                        color: Colors.green,
                        icon: Icons.arrow_downward_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStatCard(
                        label: 'Расходы',
                        value: formatCurrency(expenses),
                        color: Colors.red,
                        icon: Icons.arrow_upward_rounded,
                      ),
                    ),
                  ],
                ),

                const Divider(height: 32),

                // Долги
                const Text(
                  'Долги',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Мне должны
                _InfoRow(
                  label: 'Мне должны (начало)',
                  value: formatCurrency(startBorrowedDebts),
                  valueColor: Colors.grey.shade600,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Мне должны (конец)',
                  value: formatCurrency(endBorrowedDebts),
                  valueColor: Colors.green.shade700,
                ),

                const SizedBox(height: 16),

                // Я должен
                _InfoRow(
                  label: 'Я должен (начало)',
                  value: formatCurrency(startLentDebts),
                  valueColor: Colors.grey.shade600,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Я должен (конец)',
                  value: formatCurrency(endLentDebts),
                  valueColor: Colors.red.shade700,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;

  const _TransactionCard({
    required this.transaction,
    this.onCancel,
    this.onDelete,
  });

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} ₽';
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return 'Сегодня ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (transactionDate == today.subtract(const Duration(days: 1))) {
      return 'Вчера ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}.${date.month}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final isTransfer = transaction.type == TransactionType.transfer;
    final isCancelled = transaction.status == TransactionStatus.cancelled;

    final color = isCancelled
        ? Colors.grey
        : (isTransfer ? Colors.blue : (isIncome ? Colors.green : Colors.red));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCancelled ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCancelled
            ? Border.all(color: Colors.grey.shade300, width: 2)
            : null,
        boxShadow: isCancelled ? null : [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCancelled
                      ? Icons.cancel_rounded
                      : (isTransfer
                      ? Icons.swap_horiz_rounded
                      : (isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded)),
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            transaction.description,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              decoration: isCancelled ? TextDecoration.lineThrough : null,
                              color: isCancelled ? Colors.grey.shade600 : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCancelled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'ОТМЕНЕНА',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(transaction.date),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isTransfer
                    ? _formatCurrency(transaction.amount)
                    : '${isIncome ? '+' : '-'} ${_formatCurrency(transaction.amount)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (isTransfer)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isCancelled ? Colors.grey.shade100 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getLocationIcon(transaction.location.type),
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                transaction.location.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Icon(
                    Icons.arrow_downward_rounded,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isCancelled ? Colors.grey.shade200 : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCancelled ? Colors.grey.shade300 : Colors.blue.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getLocationIcon(transaction.transferTo!.type),
                              size: 16,
                              color: isCancelled ? Colors.grey.shade600 : Colors.blue.shade700,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                transaction.transferTo!.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isCancelled ? Colors.grey.shade700 : Colors.blue.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCancelled ? Colors.grey.shade100 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getLocationIcon(transaction.location.type),
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    transaction.location.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          if (onCancel != null && !isCancelled) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onCancel,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cancel_outlined,
                          color: Colors.orange.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Отменить транзакцию',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getLocationIcon(LocationType type) {
    switch (type) {
      case LocationType.cash:
        return Icons.payments_rounded;
      case LocationType.card:
        return Icons.credit_card_rounded;
      case LocationType.mobileWallet:
        return Icons.phone_android_rounded;
    }
  }
}