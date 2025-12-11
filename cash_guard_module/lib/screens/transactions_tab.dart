import 'package:flutter/material.dart';
import '../models/bank_card.dart';
import '../models/cash_location.dart';
import '../models/mobile_wallet.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import '../services/secure_storage_service.dart';
import '../constants/app_theme.dart';

class TransactionsTab extends StatefulWidget {
  const TransactionsTab({super.key});

  @override
  State<TransactionsTab> createState() => TransactionsTabState();
}

class TransactionsTabState extends State<TransactionsTab> with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final _storageService = SecureStorageService();
  final ScrollController _scrollController = ScrollController();

  List<Transaction> _transactions = [];
  double _initialBalance = 0;
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _headerAnimationController;
  late Animation<Offset> _headerSlideAnimation;

  bool _showFixedHeader = false;
  double _lastScrollOffset = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeInOut,
    ));

    _scrollController.addListener(_onScroll);
    _loadData();
  }

  void _onScroll() {
    final currentOffset = _scrollController.offset;
    final scrollingDown = currentOffset > _lastScrollOffset;
    final scrollingUp = currentOffset < _lastScrollOffset;

    // Показываем хедер когда проскроллили больше 200px
    if (currentOffset > 200) {
      if (!_showFixedHeader) {
        setState(() => _showFixedHeader = true);
        _headerAnimationController.forward();
      } else if (scrollingDown && _headerAnimationController.value == 1) {
        // Скрываем при скролле вниз
        _headerAnimationController.reverse();
      } else if (scrollingUp && _headerAnimationController.value == 0) {
        // Показываем при скролле вверх
        _headerAnimationController.forward();
      }
    } else {
      if (_showFixedHeader) {
        setState(() => _showFixedHeader = false);
        _headerAnimationController.reverse();
      }
    }

    _lastScrollOffset = currentOffset;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _animationController.dispose();
    _headerAnimationController.dispose();
    super.dispose();
  }

  // Публичный метод для обновления данных
  Future<void> refresh() async {
    await _loadData();
  }

  Future<void> _loadData() async {
    await _cleanOldTransactions();
    await _generateMonthlyStats();

    final transactions = await _storageService.getTransactions();
    final initialBalance = await _storageService.getInitialBalance();

    if (mounted) {
      setState(() {
        _transactions = transactions..sort((a, b) => b.date.compareTo(a.date));
        _initialBalance = initialBalance;
        _isLoading = false;
      });
      _animationController.forward();
    }
  }

  Future<void> _cleanOldTransactions() async {
    final transactions = await _storageService.getTransactions();
    final now = DateTime.now();
    final cutoffDate = DateTime(now.year, now.month - 3, now.day + 1);

    final filteredTransactions = transactions.where((t) {
      return t.date.isAfter(cutoffDate) || t.date.isAtSameMomentAs(cutoffDate);
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

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} ЅМ';
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
            const Expanded(child: Text('Отменить транзакцию?')),
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
    super.build(context);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          slivers: [
        // Хедер с градиентом (продлен вниз на 30px для округления)
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primaryDark,
                ],
              ),
            ),
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Транзакции',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                title: 'Доходы',
                                amount: _formatCurrency(_totalIncome),
                                icon: Icons.arrow_downward_rounded,
                                color: AppColors.accentGreen,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                title: 'Расходы',
                                amount: _formatCurrency(_totalExpenses),
                                icon: Icons.arrow_upward_rounded,
                                color: AppColors.accentRed,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Дополнительное пространство для округления
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),

        // Закругленное начало контента (перекрытие хедера)
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'История (3 месяца)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (_transactions.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 64,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Нет транзакций',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Добавьте первую транзакцию',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
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
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _TransactionCard(
                        transaction: transaction,
                        onCancel: transaction.canBeCancelled &&
                                 transaction.status != TransactionStatus.cancelled
                            ? () => _cancelTransaction(transaction)
                            : null,
                      ),
                    ),
                  );
                },
                childCount: _transactions.length,
              ),
            ),
          ),

        const SliverToBoxAdapter(
          child: SizedBox(height: 140),
        ),
          ],
        ),

        // Размытие снизу
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: const [0.0, 0.3, 0.6, 1.0],
                  colors: [
                    AppColors.background,
                    AppColors.background.withValues(alpha: 0.95),
                    AppColors.background.withValues(alpha: 0.6),
                    AppColors.background.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
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
              fontSize: 17,
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

  const _TransactionCard({
    required this.transaction,
    this.onCancel,
  });

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} ЅМ';
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
        ? AppColors.textMuted
        : (isTransfer ? AppColors.accentBlue : (isIncome ? AppColors.accentGreen : AppColors.accentRed));

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: isCancelled ? AppColors.surface : AppColors.cardBackground,
            borderRadius: onCancel != null && !isCancelled
                ? const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  )
                : BorderRadius.circular(20),
            border: Border.all(
              color: isCancelled ? AppColors.border : color.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isCancelled
                        ? Icons.cancel_rounded
                        : (isTransfer
                        ? Icons.swap_horiz_rounded
                        : (isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded)),
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.description,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          decoration: isCancelled ? TextDecoration.lineThrough : null,
                          color: isCancelled ? AppColors.textMuted : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatDateTime(transaction.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isTransfer
                          ? _formatCurrency(transaction.amount)
                          : '${isIncome ? '+' : '-'} ${_formatCurrency(transaction.amount)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                        decoration: isCancelled ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (isCancelled) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.textMuted.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ОТМЕНЕНА',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (isTransfer)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getLocationIcon(transaction.location.type),
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              transaction.location.name,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCancelled
                            ? AppColors.surface
                            : AppColors.accentBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getLocationIcon(transaction.transferTo!.type),
                            size: 14,
                            color: isCancelled ? AppColors.textMuted : AppColors.accentBlue,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              transaction.transferTo!.name,
                              style: TextStyle(
                                fontSize: 11,
                                color: isCancelled ? AppColors.textMuted : AppColors.accentBlue,
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
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getLocationIcon(transaction.location.type),
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          transaction.location.name,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ],
            ),
          ),
        ),
        // Добавляем кнопку отмены снаружи, чтобы не влияла на высоту основной части карточки
        if (onCancel != null && !isCancelled)
          Container(
            decoration: BoxDecoration(
              color: isCancelled ? AppColors.surface : AppColors.cardBackground,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(
                color: isCancelled ? AppColors.border : color.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Container(
                  height: 1,
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onCancel,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cancel_outlined,
                            color: AppColors.accentOrange,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Отменить транзакцию',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
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
