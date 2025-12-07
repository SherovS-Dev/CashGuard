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
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: const Center(
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
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primaryDark,
                ],
              ),
              borderRadius: BorderRadius.vertical(
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
                  valueColor: AppColors.textSecondary,
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Баланс в конце',
                  value: formatCurrency(endBalance),
                  valueColor: AppColors.primary,
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Изменение',
                  value: '${balanceChange >= 0 ? "+" : ""}${formatCurrency(balanceChange)}',
                  valueColor: balanceChange >= 0 ? AppColors.accentGreen : AppColors.accentRed,
                ),

                Divider(height: 32, color: AppColors.border),

                // Доходы и расходы
                Row(
                  children: [
                    Expanded(
                      child: _MiniStatCard(
                        label: 'Доходы',
                        value: formatCurrency(income),
                        color: AppColors.accentGreen,
                        icon: Icons.arrow_downward_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStatCard(
                        label: 'Расходы',
                        value: formatCurrency(expenses),
                        color: AppColors.accentRed,
                        icon: Icons.arrow_upward_rounded,
                      ),
                    ),
                  ],
                ),

                Divider(height: 32, color: AppColors.border),

                // Долги
                Text(
                  'Долги',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // Мне должны
                _InfoRow(
                  label: 'Мне должны (начало)',
                  value: formatCurrency(startBorrowedDebts),
                  valueColor: AppColors.textSecondary,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Мне должны (конец)',
                  value: formatCurrency(endBorrowedDebts),
                  valueColor: AppColors.accentGreen,
                ),

                const SizedBox(height: 16),

                // Я должен
                _InfoRow(
                  label: 'Я должен (начало)',
                  value: formatCurrency(startLentDebts),
                  valueColor: AppColors.textSecondary,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Я должен (конец)',
                  value: formatCurrency(endLentDebts),
                  valueColor: AppColors.accentRed,
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
            color: AppColors.textSecondary,
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
              color: AppColors.textSecondary,
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
