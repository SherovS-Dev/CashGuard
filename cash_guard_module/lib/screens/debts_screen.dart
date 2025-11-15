import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/debt.dart';
import '../services/secure_storage_service.dart';
import 'add_debt_screen.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> with SingleTickerProviderStateMixin {
  final _storageService = SecureStorageService();
  List<Debt> _debts = [];
  bool _isLoading = true;
  late TabController _tabController;

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

  Future<void> _loadDebts() async {
    final debts = await _storageService.getDebts();
    setState(() {
      _debts = debts..sort((a, b) => b.startDate.compareTo(a.startDate));
      _isLoading = false;
    });
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
    return '${amount.toStringAsFixed(2)} ₽';
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
                suffixText: '₽',
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
                    ? '✅ Долг полностью погашен!'
                    : '✅ Платеж добавлен',
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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.history_rounded, color: Colors.deepPurple.shade700),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'История платежей',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
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
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Нет платежей',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
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
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.shade200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green.shade700,
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
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${payment.date.day}.${payment.date.month}.${payment.date.year}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                if (payment.note != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    payment.note!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
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
    if (_isLoading) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.deepPurple.shade700,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
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
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.deepPurple.shade700,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addDebt,
          backgroundColor: Colors.deepPurple.shade600,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'Добавить долг',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
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
          child: Column(
            children: [
              // App Bar (extends to status bar)
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 16,
                  right: 16,
                  bottom: 12,
                ),
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
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          padding: EdgeInsets.zero, // ДОБАВЛЕНО
                          constraints: const BoxConstraints(), // ДОБАВЛЕНО
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.account_balance_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Долги и кредиты',
                                style: TextStyle(
                                  fontSize: 20, // ИЗМЕНЕНО с 22
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Управление долгами',
                                style: TextStyle(
                                  fontSize: 12, // ИЗМЕНЕНО с 13
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16), // ИЗМЕНЕНО с 20
                    // Summary Cards
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: 'Мне должны',
                            amount: _formatCurrency(_getTotalRemaining(_borrowedDebts)),
                            color: Colors.green,
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
                            color: Colors.red,
                            icon: Icons.arrow_upward_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Modern TabBar
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
                        labelColor: Colors.deepPurple.shade700,
                        unselectedLabelColor: Colors.white.withValues(alpha: 0.85),
                        labelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
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

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDebtList(_borrowedDebts, Colors.green),
                    _buildDebtList(_lentDebts, Colors.orange),
                    _buildDebtList(_credits, Colors.red),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'Нет долгов',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Нажмите + чтобы добавить',
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

    return ListView.builder(
      padding: const EdgeInsets.all(20),
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
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Status Badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(debt.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(debt.status),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(debt.status),
                          color: _getStatusColor(debt.status),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getStatusText(debt.status),
                          style: TextStyle(
                            color: _getStatusColor(debt.status),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (debt.isOverdue)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_rounded, color: Colors.red.shade700, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Просрочен',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 24),

              // Title
              Text(
                debt.description,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_rounded, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    debt.creditorDebtor,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Amount Info
              _InfoRow(
                label: 'Общая сумма',
                value: _formatCurrency(debt.totalAmount),
                valueColor: accentColor,
              ),
              if (debt.interestRate > 0) ...[
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Процентная ставка',
                  value: '${debt.interestRate.toStringAsFixed(2)}%',
                  valueColor: Colors.orange.shade700,
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Сумма с процентами',
                  value: _formatCurrency(debt.totalWithInterest),
                  valueColor: Colors.red.shade700,
                ),
              ],
              const SizedBox(height: 12),
              _InfoRow(
                label: 'Выплачено',
                value: _formatCurrency(debt.paidAmount),
                valueColor: Colors.green.shade700,
              ),
              const SizedBox(height: 12),
              _InfoRow(
                label: 'Остаток',
                value: _formatCurrency(debt.remainingWithInterest),
                valueColor: Colors.deepPurple.shade700,
                isLarge: true,
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Dates
              Row(
                children: [
                  Expanded(
                    child: _DateInfo(
                      label: 'Дата начала',
                      date: debt.startDate,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: debt.dueDate != null
                        ? _DateInfo(
                      label: 'Срок возврата',
                      date: debt.dueDate!,
                      isOverdue: debt.isOverdue,
                    )
                        : Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Срок возврата',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Не указан',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
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
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.note_rounded, size: 18, color: Colors.amber.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Заметки',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        debt.notes!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.amber.shade900,
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
                    onPressed: () {
                      Navigator.pop(context);
                      _addPayment(debt);
                    },
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
                  onPressed: () {
                    Navigator.pop(context);
                    _viewPaymentHistory(debt);
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(color: Colors.deepPurple.shade300, width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_rounded, color: Colors.deepPurple.shade700),
                      const SizedBox(width: 12),
                      Text(
                        'История платежей (${debt.payments.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(DebtStatus status) {
    switch (status) {
      case DebtStatus.active:
        return Colors.orange;
      case DebtStatus.partiallyPaid:
        return Colors.blue;
      case DebtStatus.fullyPaid:
        return Colors.green;
    }
  }

  IconData _getStatusIcon(DebtStatus status) {
    switch (status) {
      case DebtStatus.active:
        return Icons.pending_rounded;
      case DebtStatus.partiallyPaid:
        return Icons.hourglass_bottom_rounded;
      case DebtStatus.fullyPaid:
        return Icons.check_circle_rounded;
    }
  }

  String _getStatusText(DebtStatus status) {
    switch (status) {
      case DebtStatus.active:
        return 'Активный';
      case DebtStatus.partiallyPaid:
        return 'Частично погашен';
      case DebtStatus.fullyPaid:
        return 'Погашен';
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
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

  const _DebtCard({
    required this.debt,
    required this.accentColor,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onAddPayment,
  });

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} ₽';
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = debt.status == DebtStatus.fullyPaid;
    final progress = debt.totalAmount > 0 ? debt.paidAmount / debt.totalAmount : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16), // ИЗМЕНЕНО с 20
          border: Border.all( // ДОБАВЛЕНО
            color: Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200, // ИЗМЕНЕНО
              blurRadius: 8, // ИЗМЕНЕНО с 10
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16), // ИЗМЕНЕНО с 20
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header - КОМПАКТНЕЕ
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10), // ИЗМЕНЕНО с 12
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10), // ИЗМЕНЕНО с 12
                        ),
                        child: Icon(
                          debt.type == DebtType.borrowed
                              ? Icons.arrow_downward_rounded
                              : debt.type == DebtType.lent
                              ? Icons.arrow_upward_rounded
                              : Icons.account_balance_rounded,
                          color: accentColor,
                          size: 20, // ИЗМЕНЕНО с 24
                        ),
                      ),
                      const SizedBox(width: 12), // ИЗМЕНЕНО с 16
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              debt.description,
                              style: const TextStyle(
                                fontSize: 16, // ИЗМЕНЕНО с 18
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2), // ИЗМЕНЕНО с 4
                            Text(
                              debt.creditorDebtor,
                              style: TextStyle(
                                fontSize: 13, // ИЗМЕНЕНО с 14
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade600, size: 20), // ИЗМЕНЕНО
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded, size: 18, color: Colors.blue.shade700), // ИЗМЕНЕНО
                                const SizedBox(width: 12),
                                const Text('Редактировать', style: TextStyle(fontSize: 14)), // ДОБАВЛЕНО
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_rounded, size: 18, color: Colors.red.shade700), // ИЗМЕНЕНО
                                const SizedBox(width: 12),
                                const Text('Удалить', style: TextStyle(fontSize: 14)), // ДОБАВЛЕНО
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

                  const SizedBox(height: 12), // ИЗМЕНЕНО с 20

                  // Status Badge - КОМПАКТНЕЕ
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // ИЗМЕНЕНО
                        decoration: BoxDecoration(
                          color: _getStatusColor().withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12), // ИЗМЕНЕНО с 20
                          border: Border.all(
                            color: _getStatusColor(),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(),
                              color: _getStatusColor(),
                              size: 12, // ИЗМЕНЕНО с 14
                            ),
                            const SizedBox(width: 4), // ИЗМЕНЕНО с 6
                            Text(
                              _getStatusText(),
                              style: TextStyle(
                                color: _getStatusColor(),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (debt.isOverdue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // ИЗМЕНЕНО
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12), // ИЗМЕНЕНО
                            border: Border.all(color: Colors.red, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_rounded, color: Colors.red.shade700, size: 12), // ИЗМЕНЕНО
                              const SizedBox(width: 4), // ИЗМЕНЕНО
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
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16), // ИЗМЕНЕНО с 20

                  // Amount Info - КОМПАКТНЕЕ
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Остаток',
                            style: TextStyle(
                              fontSize: 12, // ИЗМЕНЕНО с 13
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatCurrency(debt.remainingWithInterest),
                            style: TextStyle(
                              fontSize: 20, // ИЗМЕНЕНО с 24
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                      if (debt.interestRate > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // ИЗМЕНЕНО
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8), // ИЗМЕНЕНО с 10
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.percent_rounded, color: Colors.orange.shade700, size: 14), // ИЗМЕНЕНО с 16
                              Text(
                                '${debt.interestRate.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 11, // ИЗМЕНЕНО с 12
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  if (!isPaid) ...[
                    const SizedBox(height: 12), // ИЗМЕНЕНО с 16
                    // Progress Bar - СДЕЛАЛИ ШИРЕ
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Выплачено: ${_formatCurrency(debt.paidAmount)}',
                              style: TextStyle(
                                fontSize: 11, // ИЗМЕНЕНО с 12
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 11, // ИЗМЕНЕНО с 12
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6), // ИЗМЕНЕНО с 8
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 10, // УВЕЛИЧЕНО с 8 - ТЕПЕРЬ ШИРЕ!
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Due Date
                  if (debt.dueDate != null) ...[
                    const SizedBox(height: 12), // ИЗМЕНЕНО с 16
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 14, // ИЗМЕНЕНО с 16
                          color: debt.isOverdue ? Colors.red.shade700 : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6), // ИЗМЕНЕНО с 8
                        Text(
                          'До ${debt.dueDate!.day}.${debt.dueDate!.month}.${debt.dueDate!.year}',
                          style: TextStyle(
                            fontSize: 12, // ИЗМЕНЕНО с 13
                            color: debt.isOverdue ? Colors.red.shade700 : Colors.grey.shade600,
                            fontWeight: debt.isOverdue ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Add Payment Button - КОМПАКТНЕЕ
            if (onAddPayment != null)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onAddPayment,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)), // ИЗМЕНЕНО
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12), // ИЗМЕНЕНО с 14
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline_rounded, color: accentColor, size: 18), // ИЗМЕНЕНО с 20
                          const SizedBox(width: 8),
                          Text(
                            'Добавить платеж',
                            style: TextStyle(
                              fontSize: 14, // ИЗМЕНЕНО с 15
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

  Color _getStatusColor() {
    switch (debt.status) {
      case DebtStatus.active:
        return Colors.orange;
      case DebtStatus.partiallyPaid:
        return Colors.blue;
      case DebtStatus.fullyPaid:
        return Colors.green;
    }
  }

  IconData _getStatusIcon() {
    switch (debt.status) {
      case DebtStatus.active:
        return Icons.pending_rounded;
      case DebtStatus.partiallyPaid:
        return Icons.hourglass_bottom_rounded;
      case DebtStatus.fullyPaid:
        return Icons.check_circle_rounded;
    }
  }

  String _getStatusText() {
    switch (debt.status) {
      case DebtStatus.active:
        return 'Активный';
      case DebtStatus.partiallyPaid:
        return 'Частично погашен';
      case DebtStatus.fullyPaid:
        return 'Погашен';
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool isLarge;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.valueColor,
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
            color: Colors.grey.shade700,
            fontWeight: isLarge ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 22 : 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _DateInfo extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool isOverdue;

  const _DateInfo({
    required this.label,
    required this.date,
    this.isOverdue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOverdue ? Colors.red.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: isOverdue
            ? Border.all(color: Colors.red.shade200, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isOverdue ? Colors.red.shade700 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${date.day}.${date.month}.${date.year}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isOverdue ? Colors.red.shade700 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}