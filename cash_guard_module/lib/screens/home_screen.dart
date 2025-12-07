import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shake/shake.dart';
import '../models/bank_card.dart';
import '../models/cash_location.dart';
import '../models/debt.dart';
import '../models/mobile_wallet.dart';
import '../services/secure_storage_service.dart';
import '../constants/app_theme.dart';
import '../utils/page_transitions.dart';
import 'debts_screen.dart';
import 'lock_screen.dart';
import 'user_setup_screen.dart';
import 'add_transaction_screen.dart';
import 'transactions_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import '../models/user.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _storageService = SecureStorageService();
  User? _user;
  bool _isLoading = true;
  List<Debt> _debts = [];
  bool _showHiddenFunds = false;
  ShakeDetector? _shakeDetector;
  int _currentIndex = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _loadUserData();
    _initShakeDetector();
  }

  void _initShakeDetector() {
    _shakeDetector = ShakeDetector.autoStart(
      onPhoneShake: (_) {
        _toggleHiddenFundsVisibility();
      },
      minimumShakeCount: 3,
      shakeSlopTimeMS: 300,
      shakeCountResetTime: 800,
      shakeThresholdGravity: 2.5,
    );
  }

  void _toggleHiddenFundsVisibility() {
    if (!mounted) return;

    final hasHiddenFunds = _user != null && (
      _user!.cashLocations.any((loc) => loc.isHidden) ||
      _user!.bankCards.any((card) => card.isHidden) ||
      _user!.mobileWallets.any((wallet) => wallet.isHidden)
    );

    if (!hasHiddenFunds) return;

    HapticFeedback.mediumImpact();

    setState(() {
      _showHiddenFunds = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Скрытые средства показаны'),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _shakeDetector?.stopListening();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = await _storageService.getUserData();
    final debts = await _storageService.getDebts();

    final initialBalance = await _storageService.getInitialBalance();
    if (initialBalance == 0 && user != null) {
      await _storageService.saveInitialBalance(user.totalBalance);
    }

    setState(() {
      _user = user;
      _debts = debts;
      _isLoading = false;
      _showHiddenFunds = false;
    });
    _animationController.forward();
  }

  Future<void> _resetPassword() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            const Text('Сбросить пароль?'),
          ],
        ),
        content: const Text(
          'Это удалит ваш текущий пароль и все финансовые данные. Вы уверены?',
          style: TextStyle(fontSize: 15),
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
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );

    if (shouldReset == true && mounted) {
      await _storageService.clearAllData();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          InstantPageRoute(page: const LockScreen()),
        );
      }
    }
  }

  Future<void> _editProfile() async {
    if (!mounted) return;

    final result = await Navigator.of(context).push(
      InstantPageRoute(page: const UserSetupScreen()),
    );

    if (result == true) {
      _loadUserData();
    }
  }

  Future<void> _addTransaction() async {
    if (!mounted) return;

    final result = await Navigator.of(context).push(
      InstantPageRoute(page: const AddTransactionScreen()),
    );

    if (result == true) {
      _loadUserData();
    }
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} ЅМ';
  }

  void _onNavTap(int index) {
    HapticFeedback.lightImpact();

    if (index == _currentIndex) return;

    switch (index) {
      case 0: // Home - уже здесь
        setState(() => _currentIndex = 0);
        break;
      case 1: // Statistics
        Navigator.of(context).push(
          InstantPageRoute(page: const StatisticsScreen()),
        ).then((_) => setState(() => _currentIndex = 0));
        break;
      case 2: // Add Transaction (центральная кнопка)
        _addTransaction();
        break;
      case 3: // Transactions
        Navigator.of(context).push(
          InstantPageRoute(page: const TransactionsScreen()),
        ).then((_) => setState(() => _currentIndex = 0));
        break;
      case 4: // Debts
        Navigator.of(context).push(
          InstantPageRoute(page: const DebtsScreen()),
        ).then((_) {
          _loadUserData();
          setState(() => _currentIndex = 0);
        });
        break;
    }
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

    if (_user == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text('CashGuard', style: TextStyle(color: AppColors.textPrimary)),
          actions: [
            IconButton(
              icon: Icon(Icons.lock_reset, color: AppColors.textPrimary),
              tooltip: 'Сбросить пароль',
              onPressed: _resetPassword,
            ),
          ],
        ),
        body: Center(
          child: Text('Ошибка загрузки данных', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Main content
          SafeArea(
            bottom: false,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: RefreshIndicator(
                onRefresh: _loadUserData,
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Привет, ${_user!.name}!',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Обзор ваших финансов',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _HeaderIconButton(
                              icon: Icons.person_rounded,
                              onTap: _editProfile,
                            ),
                            const SizedBox(width: 8),
                            _HeaderIconButton(
                              icon: Icons.settings_rounded,
                              onTap: () => Navigator.of(context).push(
                                InstantPageRoute(page: const SettingsScreen()),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Total balance card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary,
                            AppColors.primaryDark,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Общий баланс',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _formatCurrency(_user!.totalBalance),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Debts summary
                    if (_debts.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.arrow_downward_rounded,
                                        color: AppColors.accentGreen, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Мне должны',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatCurrency(_user!.getTotalBorrowedDebts(_debts)),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accentGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 50,
                              color: AppColors.border,
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.arrow_upward_rounded,
                                        color: AppColors.accentRed, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Я должен',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatCurrency(_user!.getTotalLentDebts(_debts)),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accentRed,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Balance details
                    Text(
                      'Детали баланса',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Cash locations
                    if (_user!.cashLocations.where((loc) => _showHiddenFunds || !loc.isHidden).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Наличные',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._user!.cashLocations.asMap().entries
                          .where((entry) => _showHiddenFunds || !entry.value.isHidden)
                          .map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CompactCashCard(
                              location: entry.value,
                              index: entry.key,
                              isTemporarilyVisible: entry.value.isHidden && _showHiddenFunds,
                            ),
                          )),
                    ],

                    // Mobile wallets
                    if (_user!.mobileWallets.where((wallet) => _showHiddenFunds || !wallet.isHidden).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Мобильные кошельки',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._user!.mobileWallets.asMap().entries
                          .where((entry) => _showHiddenFunds || !entry.value.isHidden)
                          .map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CompactMobileWalletCard(
                              wallet: entry.value,
                              index: entry.key,
                              isTemporarilyVisible: entry.value.isHidden && _showHiddenFunds,
                            ),
                          )),
                    ],

                    // Bank cards
                    if (_user!.bankCards.where((card) => _showHiddenFunds || !card.isHidden).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Банковские карты',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._user!.bankCards.asMap().entries
                          .where((entry) => _showHiddenFunds || !entry.value.isHidden)
                          .map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CompactBankCard(
                              card: entry.value,
                              index: entry.key,
                              isTemporarilyVisible: entry.value.isHidden && _showHiddenFunds,
                            ),
                          )),
                    ] else if (_user!.bankCards.isEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.credit_card_off_rounded,
                              size: 32,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Нет карт',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Добавьте в профиле',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
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
          ),

          // Bottom gradient fade
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
                        isSelected: _currentIndex == 3,
                        onTap: () => _onNavTap(3),
                      ),
                      _NavBarItem(
                        icon: Icons.account_balance_rounded,
                        label: 'Долги',
                        isSelected: _currentIndex == 4,
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

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 22),
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
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
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

class _CompactCashCard extends StatelessWidget {
  final CashLocation location;
  final bool isTemporarilyVisible;
  final int index;

  const _CompactCashCard({
    required this.location,
    this.isTemporarilyVisible = false,
    required this.index,
  });

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} ЅМ';
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = isTemporarilyVisible
        ? AppColors.accentOrange
        : AppColors.accentGreen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.payments_rounded,
              color: baseColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              location.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            _formatCurrency(location.amount),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: baseColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactMobileWalletCard extends StatelessWidget {
  final MobileWallet wallet;
  final int index;
  final bool isTemporarilyVisible;

  const _CompactMobileWalletCard({
    required this.wallet,
    required this.index,
    this.isTemporarilyVisible = false,
  });

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} ЅМ';
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = isTemporarilyVisible
        ? AppColors.accentOrange
        : AppColors.accentBlue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.phone_android_rounded,
              color: baseColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              wallet.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            _formatCurrency(wallet.balance),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: baseColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactBankCard extends StatelessWidget {
  final BankCard card;
  final int index;
  final bool isTemporarilyVisible;

  const _CompactBankCard({
    required this.card,
    required this.index,
    this.isTemporarilyVisible = false,
  });

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} ЅМ';
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = isTemporarilyVisible
        ? AppColors.accentOrange
        : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.credit_card_rounded,
              color: baseColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.cardName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  card.maskedCardNumber,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatCurrency(card.balance),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: baseColor,
            ),
          ),
        ],
      ),
    );
  }
}
