import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shake/shake.dart';
import '../models/bank_card.dart';
import '../models/cash_location.dart';
import '../models/debt.dart';
import '../models/mobile_wallet.dart';
import '../services/secure_storage_service.dart';
import 'debts_screen.dart';
import 'lock_screen.dart';
import 'user_setup_screen.dart';
import 'add_transaction_screen.dart';
import 'transactions_screen.dart';
import 'settings_screen.dart';
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
    print('🚀 Инициализация ShakeDetector');
    _shakeDetector = ShakeDetector.autoStart(
      onPhoneShake: (_) {
        print('📳 Shake callback вызван');
        _toggleHiddenFundsVisibility();
      },
      minimumShakeCount: 1,
      shakeSlopTimeMS: 300,
      shakeCountResetTime: 1000,
      shakeThresholdGravity: 2.0,
    );
    print('✅ ShakeDetector инициализирован');
  }

  void _toggleHiddenFundsVisibility() {
    print('🔔 Встряхивание обнаружено!');

    if (!mounted) {
      print('❌ Widget не mounted');
      return;
    }

    // Проверяем, есть ли скрытые средства
    final hasHiddenFunds = _user != null && (
      _user!.cashLocations.any((loc) => loc.isHidden) ||
      _user!.bankCards.any((card) => card.isHidden) ||
      _user!.mobileWallets.any((wallet) => wallet.isHidden)
    );

    print('📊 Есть скрытые средства: $hasHiddenFunds');

    if (!hasHiddenFunds) {
      print('❌ Нет скрытых средств для показа');
      return;
    }

    print('✅ Показываем скрытые средства');

    // Вибрация
    HapticFeedback.mediumImpact();

    // Показываем скрытые средства (они останутся до обновления страницы)
    setState(() {
      _showHiddenFunds = true;
    });
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
      // Скрываем временно показанные средства при обновлении
      _showHiddenFunds = false;
    });
    _animationController.forward();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  void _openDebts() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DebtsScreen(),
      ),
    ).then((_) => _loadUserData());
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
          MaterialPageRoute(
            builder: (context) => const LockScreen(),
          ),
        );
      }
    }
  }

  Future<void> _editProfile() async {
    if (!mounted) return;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const UserSetupScreen(),
      ),
    );

    if (result == true) {
      _loadUserData();
    }
  }

  Future<void> _addTransaction() async {
    if (!mounted) return;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddTransactionScreen(),
      ),
    );

    if (result == true) {
      _loadUserData();
    }
  }

  void _openTransactions() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TransactionsScreen(),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} ₽';
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

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('CashGuard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.lock_reset),
              tooltip: 'Сбросить пароль',
              onPressed: _resetPassword,
            ),
          ],
        ),
        body: const Center(
          child: Text('Ошибка загрузки данных'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.deepPurple.shade600,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Привет, ${_user!.name}! 👋',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Обзор ваших финансов',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white),
            tooltip: 'Настройки',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: _loadUserData,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Общий баланс - компактная карточка
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.deepPurple.shade500,
                      Colors.deepPurple.shade700,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.shade200.withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Общий баланс',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        // Подсказка о встряхивании
                        if (_user!.cashLocations.any((loc) => loc.isHidden) ||
                            _user!.bankCards.any((card) => card.isHidden) ||
                            _user!.mobileWallets.any((wallet) => wallet.isHidden))
                          Icon(
                            Icons.vibration,
                            color: Colors.white.withValues(alpha: 0.5),
                            size: 18,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatCurrency(_user!.totalBalance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (_user!.cashLocations.any((loc) => loc.isHidden) ||
                        _user!.bankCards.any((card) => card.isHidden) ||
                        _user!.mobileWallets.any((wallet) => wallet.isHidden))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Встряхните телефон для просмотра скрытых',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Быстрые действия
              Row(
                children: [
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.history_rounded,
                      label: 'Транзакции',
                      color: Colors.blue,
                      onTap: _openTransactions,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.account_balance_rounded,
                      label: 'Долги',
                      color: Colors.orange,
                      onTap: _openDebts,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.edit_rounded,
                      label: 'Профиль',
                      color: Colors.green,
                      onTap: _editProfile,
                    ),
                  ),
                ],
              ),

              // Долги - компактная карточка
              if (_debts.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Долги и кредиты',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Мне должны',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatCurrency(_user!.getTotalBorrowedDebts(_debts)),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey.shade200,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Я должен',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatCurrency(_user!.getTotalLentDebts(_debts)),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Детали баланса
              Text(
                'Детали баланса',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),

              // Отображаем каждое место хранения наличных отдельно
              if (_user!.cashLocations.where((loc) => _showHiddenFunds || !loc.isHidden).isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Наличные',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                ..._user!.cashLocations.asMap().entries
                    .where((entry) => _showHiddenFunds || !entry.value.isHidden)
                    .map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CompactCashCard(
                        location: entry.value,
                        index: entry.key,
                        isTemporarilyVisible: entry.value.isHidden && _showHiddenFunds,
                      ),
                    )).toList(),
              ],

              if (_user!.mobileWallets.where((wallet) => _showHiddenFunds || !wallet.isHidden).isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Мобильные кошельки',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                ..._user!.mobileWallets.asMap().entries
                    .where((entry) => _showHiddenFunds || !entry.value.isHidden)
                    .map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CompactMobileWalletCard(
                        wallet: entry.value,
                        index: entry.key,
                        isTemporarilyVisible: entry.value.isHidden && _showHiddenFunds,
                      ),
                    )).toList(),
              ],

              if (_user!.bankCards.where((card) => _showHiddenFunds || !card.isHidden).isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Банковские карты',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                ..._user!.bankCards.asMap().entries
                    .where((entry) => _showHiddenFunds || !entry.value.isHidden)
                    .map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CompactBankCard(
                        card: entry.value,
                        index: entry.key,
                        isTemporarilyVisible: entry.value.isHidden && _showHiddenFunds,
                      ),
                    )).toList(),
              ] else if (_user!.bankCards.isEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.credit_card_off_rounded,
                        size: 32,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Нет карт',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Добавьте в профиле',
                              style: TextStyle(
                                color: Colors.grey.shade500,
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

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTransaction,
        backgroundColor: Colors.deepPurple.shade600,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Транзакция',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
    return '${amount.toStringAsFixed(2)} ₽';
  }

  List<List<Color>> _getGradientColors() {
    return [
      [Colors.green.shade400, Colors.green.shade600],
      [Colors.teal.shade400, Colors.teal.shade600],
      [const Color(0xFF9CCC65), const Color(0xFF689F38)],
      [const Color(0xFF66BB6A), const Color(0xFF43A047)],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getGradientColors()[index % _getGradientColors().length];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isTemporarilyVisible
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.orange.shade400, Colors.orange.shade600],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isTemporarilyVisible
                ? Colors.orange.shade300.withValues(alpha: 0.5)
                : colors[0].withValues(alpha: 0.5),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatCurrency(location.amount),
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
    return '${amount.toStringAsFixed(2)} ₽';
  }

  List<List<Color>> _getGradientColors() {
    return [
      [const Color(0xFF11998e), const Color(0xFF38ef7d)],
      [const Color(0xFF2193b0), const Color(0xFF6dd5ed)],
      [const Color(0xFFee0979), const Color(0xFFff6a00)],
      [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getGradientColors()[index % _getGradientColors().length];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isTemporarilyVisible
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.orange.shade400, Colors.orange.shade600],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isTemporarilyVisible
                ? Colors.orange.shade300.withValues(alpha: 0.5)
                : colors[0].withValues(alpha: 0.5),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.phone_android_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wallet.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatCurrency(wallet.balance),
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
    return '${amount.toStringAsFixed(2)} ₽';
  }

  List<List<Color>> _getGradientColors() {
    return [
      [const Color(0xFF667eea), const Color(0xFF764ba2)],
      [const Color(0xFFf093fb), const Color(0xFFf5576c)],
      [const Color(0xFF4facfe), const Color(0xFF00f2fe)],
      [const Color(0xFF43e97b), const Color(0xFF38f9d7)],
      [const Color(0xFFfa709a), const Color(0xFFfee140)],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getGradientColors()[index % _getGradientColors().length];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isTemporarilyVisible
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.orange.shade400, Colors.orange.shade600],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isTemporarilyVisible
                ? Colors.orange.shade300.withValues(alpha: 0.5)
                : colors[0].withValues(alpha: 0.5),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.credit_card_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.cardName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  card.maskedCardNumber,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatCurrency(card.balance),
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