import 'package:flutter/material.dart';
import '../models/debt.dart';
import '../services/secure_storage_service.dart';
import '../constants/app_theme.dart';
import 'add_debt_screen.dart';

class DebtsTab extends StatefulWidget {
  const DebtsTab({super.key});

  @override
  State<DebtsTab> createState() => DebtsTabState();
}

class DebtsTabState extends State<DebtsTab> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _storageService = SecureStorageService();
  List<Debt> _debts = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDebts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Публичный метод для обновления данных
  Future<void> refresh() async {
    await _loadDebts();
  }

  Future<void> _loadDebts() async {
    final debts = await _storageService.getDebts();
    if (mounted) {
      setState(() {
        _debts = debts..sort((a, b) => b.startDate.compareTo(a.startDate));
        _isLoading = false;
      });
    }
  }

  List<Debt> get _borrowedDebts {
    return _debts.where((d) => d.type == DebtType.borrowed).toList();
  }

  List<Debt> get _lentDebts {
    return _debts.where((d) => d.type == DebtType.lent).toList();
  }

  List<Debt> get _credits {
    return _debts.where((d) => d.type == DebtType.credit).toList();
  }

  double _getTotalRemaining(List<Debt> debts) {
    return debts
        .where((d) => d.status != DebtStatus.fullyPaid)
        .fold(0, (sum, debt) => sum + debt.remainingWithInterest);
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} ЅМ';
  }

  Future<void> _addDebt() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddDebtScreen(),
      ),
    );

    if (result == true) {
      _loadDebts();
    }
  }

  Future<void> _editDebt(Debt debt) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddDebtScreen(debtToEdit: debt),
      ),
    );

    if (result == true) {
      _loadDebts();
    }
  }

  Future<void> _deleteDebt(Debt debt) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            const Text('Удалить долг?'),
          ],
        ),
        content: Text(
          'Вы уверены, что хотите удалить "${debt.description}"?\n\nВся информация о платежах будет потеряна.',
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
      await _storageService.deleteDebt(debt.id);
      _loadDebts();
    }
  }

  Future<void> _addPayment(Debt debt) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Добавить платеж'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Остаток: ${_formatCurrency(debt.remainingWithInterest)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Сумма платежа',
                hintText: '0.00',
                suffixText: 'ЅМ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: 'Заметка (необязательно)',
                hintText: 'Например: Частичная оплата',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.deepPurple,
            ),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );

    if (shouldAdd == true && amountController.text.isNotEmpty) {
      final amount = double.tryParse(amountController.text);
      if (amount != null && amount > 0) {
        final payment = DebtPayment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          amount: amount,
          date: DateTime.now(),
          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        );

        final updatedPayments = [...debt.payments, payment];
        final totalPaid = updatedPayments.fold(0.0, (sum, p) => sum + p.amount);

        DebtStatus newStatus;
        if (totalPaid >= debt.totalAmount) {
          newStatus = DebtStatus.fullyPaid;
        } else if (totalPaid > 0) {
          newStatus = DebtStatus.partiallyPaid;
        } else {
          newStatus = DebtStatus.active;
        }

        final updatedDebt = debt.copyWith(
          payments: updatedPayments,
          status: newStatus,
        );

        await _storageService.updateDebt(updatedDebt);
        _loadDebts();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                newStatus == DebtStatus.fullyPaid
                    ? 'Долг полностью погашен!'
                    : 'Платеж добавлен',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<void> _viewPaymentHistory(Debt debt) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.history_rounded, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'История платежей',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: debt.payments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.payments_outlined,
                              size: 64,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Нет платежей',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(20),
                        itemCount: debt.payments.length,
                        itemBuilder: (context, index) {
                          final payment = debt.payments[debt.payments.length - 1 - index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.accentGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.accentGreen.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentGreen.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.accentGreen,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatCurrency(payment.amount),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.accentGreen,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${payment.date.day}.${payment.date.month}.${payment.date.year}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      if (payment.note != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          payment.note!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return Column(
      children: [
        // Header
        Container(
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
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Долги и кредиты',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _addDebt,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'Мне должны',
                          amount: _formatCurrency(_getTotalRemaining(_borrowedDebts)),
                          icon: Icons.arrow_downward_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Я должен',
                          amount: _formatCurrency(
                            _getTotalRemaining(_lentDebts) + _getTotalRemaining(_credits),
                          ),
                          icon: Icons.arrow_upward_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // TabBar
                  Container(
                    height: 45,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: AppColors.primaryDark,
                      unselectedLabelColor: Colors.white.withValues(alpha: 0.85),
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      splashFactory: NoSplash.splashFactory,
                      overlayColor: WidgetStateProperty.all(Colors.transparent),
                      tabs: const [
                        Tab(text: 'Мне должны'),
                        Tab(text: 'Я должен'),
                        Tab(text: 'Кредиты'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDebtList(_borrowedDebts, AppColors.accentGreen),
              _buildDebtList(_lentDebts, AppColors.accentOrange),
              _buildDebtList(_credits, AppColors.accentRed),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDebtList(List<Debt> debts, Color accentColor) {
    if (debts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_open_rounded,
                size: 64,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 16),
              Text(
                'Нет долгов',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Нажмите + чтобы добавить',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
      itemCount: debts.length,
      itemBuilder: (context, index) {
        final debt = debts[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _DebtCard(
            debt: debt,
            accentColor: accentColor,
            onTap: () => _showDebtDetails(debt, accentColor),
            onEdit: () => _editDebt(debt),
            onDelete: () => _deleteDebt(debt),
            onAddPayment: debt.status != DebtStatus.fullyPaid ? () => _addPayment(debt) : null,
            formatCurrency: _formatCurrency,
          ),
        );
      },
    );
  }

  void _showDebtDetails(Debt debt, Color accentColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DebtDetailsSheet(
        debt: debt,
        accentColor: accentColor,
        formatCurrency: _formatCurrency,
        onAddPayment: () {
          Navigator.pop(context);
          _addPayment(debt);
        },
        onViewHistory: () {
          Navigator.pop(context);
          _viewPaymentHistory(debt);
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
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

class _DebtCard extends StatelessWidget {
  final Debt debt;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onAddPayment;
  final String Function(double) formatCurrency;

  const _DebtCard({
    required this.debt,
    required this.accentColor,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onAddPayment,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final isPaid = debt.status == DebtStatus.fullyPaid;
    final progress = debt.totalAmount > 0 ? debt.paidAmount / debt.totalAmount : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          debt.type == DebtType.borrowed
                              ? Icons.arrow_downward_rounded
                              : debt.type == DebtType.lent
                                  ? Icons.arrow_upward_rounded
                                  : Icons.account_balance_rounded,
                          color: accentColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              debt.description,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              debt.creditorDebtor,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary, size: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded, size: 18, color: Colors.blue.shade700),
                                const SizedBox(width: 12),
                                const Text('Редактировать', style: TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_rounded, size: 18, color: Colors.red.shade700),
                                const SizedBox(width: 12),
                                const Text('Удалить', style: TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'edit') {
                            onEdit();
                          } else if (value == 'delete') {
                            onDelete();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatusBadge(status: debt.status),
                      if (debt.isOverdue) ...[
                        const SizedBox(width: 8),
                        _OverdueBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Остаток',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatCurrency(debt.remainingWithInterest),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                      if (debt.interestRate > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.accentOrange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.percent_rounded, color: AppColors.accentOrange, size: 14),
                              Text(
                                '${debt.interestRate.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accentOrange,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (!isPaid) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Выплачено: ${formatCurrency(debt.paidAmount)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: AppColors.surface,
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      ),
                    ),
                  ],
                  if (debt.dueDate != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: debt.isOverdue ? AppColors.accentRed : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'До ${debt.dueDate!.day}.${debt.dueDate!.month}.${debt.dueDate!.year}',
                          style: TextStyle(
                            fontSize: 12,
                            color: debt.isOverdue ? AppColors.accentRed : AppColors.textSecondary,
                            fontWeight: debt.isOverdue ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (onAddPayment != null)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onAddPayment,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline_rounded, color: accentColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Добавить платеж',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final DebtStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String text;

    switch (status) {
      case DebtStatus.active:
        color = Colors.orange;
        icon = Icons.pending_rounded;
        text = 'Активный';
        break;
      case DebtStatus.partiallyPaid:
        color = Colors.blue;
        icon = Icons.hourglass_bottom_rounded;
        text = 'Частично погашен';
        break;
      case DebtStatus.fullyPaid:
        color = Colors.green;
        icon = Icons.check_circle_rounded;
        text = 'Погашен';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverdueBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_rounded, color: Colors.red.shade700, size: 12),
          const SizedBox(width: 4),
          Text(
            'Просрочен',
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtDetailsSheet extends StatelessWidget {
  final Debt debt;
  final Color accentColor;
  final String Function(double) formatCurrency;
  final VoidCallback onAddPayment;
  final VoidCallback onViewHistory;

  const _DebtDetailsSheet({
    required this.debt,
    required this.accentColor,
    required this.formatCurrency,
    required this.onAddPayment,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Status Badges
            Row(
              children: [
                _StatusBadge(status: debt.status),
                if (debt.isOverdue) ...[
                  const SizedBox(width: 8),
                  _OverdueBadge(),
                ],
              ],
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              debt.description,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_rounded, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  debt.creditorDebtor,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Divider(color: AppColors.border),
            const SizedBox(height: 16),

            // Amount Info
            _DetailRow(label: 'Общая сумма', value: formatCurrency(debt.totalAmount), color: accentColor),
            if (debt.interestRate > 0) ...[
              const SizedBox(height: 12),
              _DetailRow(label: 'Процентная ставка', value: '${debt.interestRate.toStringAsFixed(2)}%', color: AppColors.accentOrange),
              const SizedBox(height: 12),
              _DetailRow(label: 'Сумма с процентами', value: formatCurrency(debt.totalWithInterest), color: AppColors.accentRed),
            ],
            const SizedBox(height: 12),
            _DetailRow(label: 'Выплачено', value: formatCurrency(debt.paidAmount), color: AppColors.accentGreen),
            const SizedBox(height: 12),
            _DetailRow(label: 'Остаток', value: formatCurrency(debt.remainingWithInterest), color: AppColors.primary, isLarge: true),

            const SizedBox(height: 24),
            Divider(color: AppColors.border),
            const SizedBox(height: 16),

            // Dates
            Row(
              children: [
                Expanded(child: _DateCard(label: 'Дата начала', date: debt.startDate)),
                const SizedBox(width: 16),
                Expanded(
                  child: debt.dueDate != null
                      ? _DateCard(label: 'Срок возврата', date: debt.dueDate!, isOverdue: debt.isOverdue)
                      : Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Срок возврата', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              Text('Не указан', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                ),
              ],
            ),

            if (debt.notes != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accentOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.note_rounded, size: 18, color: AppColors.accentOrange),
                        SizedBox(width: 8),
                        Text(
                          'Заметки',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentOrange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      debt.notes!,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action Buttons
            if (debt.status != DebtStatus.fullyPaid)
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: onAddPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_rounded, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        'Добавить платеж',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (debt.payments.isNotEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onViewHistory,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  side: const BorderSide(color: AppColors.primary, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history_rounded, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text(
                      'История платежей (${debt.payments.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isLarge;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.color,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isLarge ? 16 : 14,
            color: AppColors.textSecondary,
            fontWeight: isLarge ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 22 : 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _DateCard extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool isOverdue;

  const _DateCard({
    required this.label,
    required this.date,
    this.isOverdue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOverdue ? AppColors.accentRed.withValues(alpha: 0.1) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: isOverdue ? Border.all(color: AppColors.accentRed.withValues(alpha: 0.3), width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isOverdue ? AppColors.accentRed : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${date.day}.${date.month}.${date.year}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isOverdue ? AppColors.accentRed : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
