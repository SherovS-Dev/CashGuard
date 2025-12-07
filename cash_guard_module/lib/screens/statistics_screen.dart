import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/secure_storage_service.dart';
import '../constants/app_theme.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with SingleTickerProviderStateMixin {
  final _storageService = SecureStorageService();
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
    final monthly = await _storageService.getMonthlySnapshots();
    final yearly = await _storageService.getYearlySnapshots();

    setState(() {
      _monthlySnapshots = monthly;
      _yearlySnapshots = yearly;
      _isLoading = false;
    });
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} ЅМ';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: true,
          child: Column(
            children: [
              // Header with gradient background
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
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      children: [
                        // Title and back button
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            const Expanded(
                              child: Text(
                                'Статистика',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
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
                            labelColor: AppColors.primaryDark,
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
                              Tab(text: 'По месяцам'),
                              Tab(text: 'По годам'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
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
              const SizedBox(height: 16),
            ],
          ),
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
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 16),
              Text(
                'Нет месячной статистики',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Статистика создается автоматически\nв начале каждого месяца',
                textAlign: TextAlign.center,
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

    final sortedKeys = _monthlySnapshots.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final key = sortedKeys[index];
        final snapshot = _monthlySnapshots[key] as Map<String, dynamic>;
        final date = DateTime.parse(snapshot['month']);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SnapshotCard(
            title: '${_getMonthName(date.month)} ${date.year}',
            snapshot: snapshot,
            formatCurrency: _formatCurrency,
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
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 16),
              Text(
                'Нет годовой статистики',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Статистика создается автоматически\n1 января каждого года',
                textAlign: TextAlign.center,
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

    final sortedKeys = _yearlySnapshots.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final key = sortedKeys[index];
        final snapshot = _yearlySnapshots[key] as Map<String, dynamic>;
        final date = DateTime.parse(snapshot['year']);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SnapshotCard(
            title: '${date.year} год',
            snapshot: snapshot,
            formatCurrency: _formatCurrency,
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

  String _shortCurrency(double amount) {
    if (amount.abs() >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount.abs() >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final startBalance = (snapshot['startBalance'] ?? 0).toDouble();
    final endBalance = (snapshot['endBalance'] ?? 0).toDouble();
    final income = (snapshot['income'] ?? 0).toDouble();
    final expenses = (snapshot['expenses'] ?? 0).toDouble();
    final transactionCount = snapshot['transactionCount'] ?? 0;
    final balanceChange = endBalance - startBalance;

    final startBorrowedDebts = (snapshot['startBorrowedDebts'] ?? 0).toDouble();
    final endBorrowedDebts = (snapshot['endBorrowedDebts'] ?? 0).toDouble();
    final startLentDebts = (snapshot['startLentDebts'] ?? 0).toDouble();
    final endLentDebts = (snapshot['endLentDebts'] ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Row 1: Title + Balance change
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _shortCurrency(startBalance),
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
              Icon(Icons.arrow_right_alt, size: 14, color: AppColors.textMuted),
              Text(
                '${_shortCurrency(endBalance)}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (balanceChange >= 0 ? AppColors.accentGreen : AppColors.accentRed)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${balanceChange >= 0 ? "+" : ""}${_shortCurrency(balanceChange)}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: balanceChange >= 0 ? AppColors.accentGreen : AppColors.accentRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: Income, Expense, Debts info
          Row(
            children: [
              // Income
              const Icon(Icons.south_west, size: 12, color: AppColors.accentGreen),
              const SizedBox(width: 2),
              Text(
                _shortCurrency(income),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentGreen,
                ),
              ),
              const SizedBox(width: 10),
              // Expense
              const Icon(Icons.north_east, size: 12, color: AppColors.accentRed),
              const SizedBox(width: 2),
              Text(
                _shortCurrency(expenses),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentRed,
                ),
              ),
              const SizedBox(width: 10),
              // Divider
              Container(width: 1, height: 12, color: AppColors.border),
              const SizedBox(width: 10),
              // Lent (Мне должны)
              Text('Дали:', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
              const SizedBox(width: 3),
              Text(
                _shortCurrency(endBorrowedDebts),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.accentGreen),
              ),
              const SizedBox(width: 8),
              // Borrowed (Я должен)
              Text('Взял:', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
              const SizedBox(width: 3),
              Text(
                _shortCurrency(endLentDebts),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.accentRed),
              ),
              const Spacer(),
              // Transaction count
              Text(
                '$transactionCount тр.',
                style: TextStyle(fontSize: 9, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
