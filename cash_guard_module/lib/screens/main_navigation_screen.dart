import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_theme.dart';
import 'home_tab.dart';
import 'statistics_tab.dart';
import 'transactions_tab.dart';
import 'debts_tab.dart';
import 'add_transaction_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final Function(ThemeMode)? onThemeChanged;

  const MainNavigationScreen({super.key, this.onThemeChanged});

  @override
  State<MainNavigationScreen> createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // GlobalKeys для обновления табов
  final _homeKey = GlobalKey<HomeTabState>();
  final _statisticsKey = GlobalKey<StatisticsTabState>();
  final _transactionsKey = GlobalKey<TransactionsTabState>();
  final _debtsKey = GlobalKey<DebtsTabState>();

  void _onNavTap(int index) {
    HapticFeedback.lightImpact();

    if (index == 2) {
      // Центральная кнопка - добавить транзакцию
      _addTransaction();
      return;
    }

    // Преобразуем индекс (пропускаем центральную кнопку)
    final actualIndex = index > 2 ? index - 1 : index;

    if (actualIndex == _currentIndex) return;

    setState(() => _currentIndex = actualIndex);
  }

  Future<void> _addTransaction() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddTransactionScreen(),
      ),
    );

    if (result == true) {
      // Обновляем все табы
      _refreshAllTabs();
    }
  }

  void _refreshAllTabs() {
    _homeKey.currentState?.refresh();
    _statisticsKey.currentState?.refresh();
    _transactionsKey.currentState?.refresh();
    _debtsKey.currentState?.refresh();
  }

  // Публичный метод для обновления из дочерних виджетов
  void refreshData() {
    _refreshAllTabs();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? AppColors.backgroundGradientDark.last
        : AppColors.backgroundGradientLight.last;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Контент табов с сохранением состояния
          IndexedStack(
            index: _currentIndex,
            children: [
              HomeTab(key: _homeKey),
              StatisticsTab(key: _statisticsKey),
              TransactionsTab(key: _transactionsKey),
              DebtsTab(key: _debtsKey),
            ],
          ),

          // Градиент снизу
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: const [0.0, 0.4, 0.7, 1.0],
                    colors: [
                      bgColor,
                      bgColor.withValues(alpha: 0.95),
                      bgColor.withValues(alpha: 0.6),
                      bgColor.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Navigation Bar
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _NavBarItem(
                        icon: Icons.home_rounded,
                        label: 'Главная',
                        isSelected: _currentIndex == 0,
                        onTap: () => _onNavTap(0),
                      ),
                      _NavBarItem(
                        icon: Icons.bar_chart_rounded,
                        label: 'Статистика',
                        isSelected: _currentIndex == 1,
                        onTap: () => _onNavTap(1),
                      ),
                      _NavBarAddButton(
                        onTap: () => _onNavTap(2),
                      ),
                      _NavBarItem(
                        icon: Icons.receipt_long_rounded,
                        label: 'История',
                        isSelected: _currentIndex == 2,
                        onTap: () => _onNavTap(3),
                      ),
                      _NavBarItem(
                        icon: Icons.account_balance_rounded,
                        label: 'Долги',
                        isSelected: _currentIndex == 3,
                        onTap: () => _onNavTap(4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBarAddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _NavBarAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          // ignore: prefer_const_constructors
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [
              AppColors.primary,
              AppColors.primaryDark,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
