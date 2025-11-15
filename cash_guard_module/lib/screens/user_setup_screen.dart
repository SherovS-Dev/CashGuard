import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shake/shake.dart';
import '../models/bank_card.dart';
import '../models/cash_location.dart';
import '../models/mobile_wallet.dart';
import '../services/secure_storage_service.dart';
import '../services/backup_service.dart';
import 'home_screen.dart';
import '../models/user.dart';

class UserSetupScreen extends StatefulWidget {
  const UserSetupScreen({super.key});

  @override
  State<UserSetupScreen> createState() => _UserSetupScreenState();
}

class _UserSetupScreenState extends State<UserSetupScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cashInHandController = TextEditingController();
  final _storageService = SecureStorageService();
  final _backupService = BackupService();

  final List<BankCardInput> _bankCards = [];
  final List<CashLocationInput> _cashLocations = [];
  final List<MobileWalletInput> _mobileWallets = [];

  bool _isLoading = true;
  bool _isEditMode = false;
  bool _isRestoring = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  ShakeDetector? _shakeDetector;
  bool _showHiddenFunds = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _loadExistingData();
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
    final hasHiddenFunds = _cashLocations.any((loc) => loc.isHidden) ||
        _bankCards.any((card) => card.isHidden) ||
        _mobileWallets.any((wallet) => wallet.isHidden);

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

  Future<void> _loadExistingData() async {
    final user = await _storageService.getUserData();

    if (user != null) {
      setState(() {
        _isEditMode = true;
        _nameController.text = user.name;
        // Скрываем временно показанные средства при загрузке данных
        _showHiddenFunds = false;

        // Загружаем основные наличные из cashLocations
        if (user.cashLocations.isNotEmpty) {
          final mainCash = user.cashLocations.firstWhere(
                (loc) => loc.name == 'Наличные в руке',
            orElse: () => user.cashLocations.first,
          );
          _cashInHandController.text = mainCash.amount.toString();

          // Загружаем остальные места
          for (var location in user.cashLocations) {
            if (location.name != 'Наличные в руке') {
              final locInput = CashLocationInput();
              locInput.nameController.text = location.name;
              locInput.amountController.text = location.amount.toString();
              locInput.isHidden = location.isHidden;
              _cashLocations.add(locInput);
            }
          }
        }

        // Загружаем банковские карты
        for (var card in user.bankCards) {
          final cardInput = BankCardInput();
          cardInput.nameController.text = card.cardName;
          cardInput.numberController.text = card.cardNumber;
          cardInput.balanceController.text = card.balance.toString();
          cardInput.bankController.text = card.bankName ?? '';
          cardInput.isHidden = card.isHidden;
          _bankCards.add(cardInput);
        }

        // Загружаем мобильные кошельки
        for (var wallet in user.mobileWallets) {
          final walletInput = MobileWalletInput();
          walletInput.nameController.text = wallet.name;
          walletInput.phoneController.text = wallet.phoneNumber;
          walletInput.balanceController.text = wallet.balance.toString();
          walletInput.isHidden = wallet.isHidden;
          _mobileWallets.add(walletInput);
        }
      });
    }

    setState(() {
      _isLoading = false;
      // Убеждаемся что скрытые средства не показаны при первой загрузке
      if (user == null) {
        _showHiddenFunds = false;
      }
    });
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cashInHandController.dispose();
    _animationController.dispose();
    _shakeDetector?.stopListening();
    for (var card in _bankCards) {
      card.dispose();
    }
    for (var location in _cashLocations) {
      location.dispose();
    }
    for (var wallet in _mobileWallets) {
      wallet.dispose();
    }
    super.dispose();
  }

  void _addBankCard() {
    setState(() {
      _bankCards.add(BankCardInput());
    });
  }

  void _removeBankCard(int index) {
    setState(() {
      _bankCards[index].dispose();
      _bankCards.removeAt(index);
    });
  }

  void _addCashLocation() {
    setState(() {
      _cashLocations.add(CashLocationInput());
    });
  }

  void _removeCashLocation(int index) {
    setState(() {
      _cashLocations[index].dispose();
      _cashLocations.removeAt(index);
    });
  }

  void _addMobileWallet() {
    setState(() {
      _mobileWallets.add(MobileWalletInput());
    });
  }

  void _removeMobileWallet(int index) {
    setState(() {
      _mobileWallets[index].dispose();
      _mobileWallets.removeAt(index);
    });
  }

  void _showPersonalInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade700],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_circle_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Личная информация',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Ваше имя',
                hintText: 'Например: Иван',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cashInHandController,
              decoration: InputDecoration(
                labelText: 'Наличные в руке',
                hintText: '0.00',
                suffixText: '₽',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Отмена'),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade700],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () {
                setState(() {});
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreFromBackup() async {
    setState(() {
      _isRestoring = true;
    });

    try {
      final result = await _backupService.pickAndRestoreBackup();

      if (!mounted) return;

      if (result == null) {
        throw Exception('Не удалось прочитать файл');
      }

      if (result['success'] == true) {
        // Показываем результаты восстановления
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 12),
                const Text('Успешно!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Данные успешно восстановлены:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _RestoreInfoRow(
                  icon: Icons.person,
                  label: 'Профиль',
                  value: result['userRestored'] ? 'Восстановлен' : 'Не найден',
                  isSuccess: result['userRestored'],
                ),
                _RestoreInfoRow(
                  icon: Icons.receipt,
                  label: 'Транзакции',
                  value: '${result['transactionsCount']} шт.',
                  isSuccess: result['transactionsCount'] > 0,
                ),
                _RestoreInfoRow(
                  icon: Icons.account_balance,
                  label: 'Долги',
                  value: '${result['debtsCount']} шт.',
                  isSuccess: result['debtsCount'] > 0,
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Переходим на главный экран
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const HomeScreen(),
                    ),
                  );
                },
                child: const Text('Продолжить'),
              ),
            ],
          ),
        );
      } else {
        throw Exception(result['error'] ?? 'Неизвестная ошибка');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Ошибка восстановления: $e'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Собираем все места хранения наличных
    final List<CashLocation> cashLocations = [];

    // Добавляем основные наличные
    final mainCash = double.tryParse(_cashInHandController.text) ?? 0;
    cashLocations.add(CashLocation(
      id: 'main_cash',
      name: 'Наличные в руке',
      amount: mainCash,
    ));

    // Добавляем дополнительные места
    for (var i = 0; i < _cashLocations.length; i++) {
      final location = _cashLocations[i];
      cashLocations.add(CashLocation(
        id: 'cash_location_$i',
        name: location.nameController.text.trim(),
        amount: double.tryParse(location.amountController.text) ?? 0,
        isHidden: location.isHidden,
      ));
    }

    // Собираем банковские карты
    final bankCards = _bankCards.map((input) {
      return BankCard(
        cardName: input.nameController.text.trim(),
        cardNumber: input.numberController.text.trim(),
        balance: double.tryParse(input.balanceController.text) ?? 0,
        bankName: input.bankController.text.trim().isEmpty
            ? null
            : input.bankController.text.trim(),
        isHidden: input.isHidden,
      );
    }).toList();

    // Собираем мобильные кошельки
    final mobileWallets = _mobileWallets.map((input) {
      return MobileWallet(
        name: input.nameController.text.trim(),
        phoneNumber: input.phoneController.text.trim(),
        balance: double.tryParse(input.balanceController.text) ?? 0,
        isHidden: input.isHidden,
      );
    }).toList();

    final user = User(
      name: _nameController.text.trim(),
      cashLocations: cashLocations,
      bankCards: bankCards,
      mobileWallets: mobileWallets,
    );

    await _storageService.saveUserData(user);

    if (!_isEditMode) {
      await _storageService.saveInitialBalance(user.totalBalance);
    }

    if (!mounted) return;

    // В режиме редактирования просто возвращаемся назад
    if (_isEditMode) {
      Navigator.of(context).pop(true);
    } else {
      // В режиме создания переходим на главный экран
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
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

    if (_isRestoring) {
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 24),
                Text(
                  'Восстановление данных...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar с счетчиками
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        if (_isEditMode)
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        else
                          const SizedBox.shrink(),
                        if (_isEditMode) const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _isEditMode ? Icons.edit_rounded : Icons.person_add_rounded,
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
                                _isEditMode ? 'Редактирование профиля' : 'Настройка профиля',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isEditMode
                                    ? 'Измените свои данные'
                                    : 'Добавьте свои финансовые данные',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Счетчики
                    if (_bankCards.isNotEmpty || _cashLocations.isNotEmpty || _mobileWallets.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (_bankCards.isNotEmpty)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.credit_card_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_bankCards.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (_bankCards.isNotEmpty && (_cashLocations.isNotEmpty || _mobileWallets.isNotEmpty))
                            const SizedBox(width: 8),
                          if (_cashLocations.isNotEmpty)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.location_on_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_cashLocations.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (_mobileWallets.isNotEmpty && (_bankCards.isNotEmpty || _cashLocations.isNotEmpty))
                            const SizedBox(width: 8),
                          if (_mobileWallets.isNotEmpty)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.phone_android_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_mobileWallets.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Form Content
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Кнопка восстановления (только для нового пользователя)
                        if (!_isEditMode) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue.shade400, Colors.blue.shade600],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _restoreFromBackup,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.restore_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Восстановить данные',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Загрузите резервную копию',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'или создайте новый профиль',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Personal Info Section
                        _SectionHeader(
                          icon: Icons.account_circle_rounded,
                          title: 'Личная информация',
                          color: Colors.deepPurple.shade600,
                        ),
                        const SizedBox(height: 12),

                        // Personal Info Card
                        GestureDetector(
                          onTap: () => _showPersonalInfoDialog(),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.deepPurple.shade400,
                                  Colors.deepPurple.shade700,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.deepPurple.shade300.withValues(alpha: 0.5),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.account_circle_rounded,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _nameController.text.isEmpty
                                            ? 'Ваше имя'
                                            : _nameController.text,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.payments_rounded,
                                            color: Colors.white70,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Наличные: ${(double.tryParse(_cashInHandController.text) ?? 0.0).toStringAsFixed(2)} ₽',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _showPersonalInfoDialog(),
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Additional Cash Locations Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: _SectionHeader(
                                icon: Icons.account_balance_wallet_rounded,
                                title: 'Другие места (наличные)',
                                color: Colors.orange.shade600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orange.shade400,
                                    Colors.orange.shade600,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.shade200,
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: _addCashLocation,
                                icon: const Icon(Icons.add_rounded),
                                color: Colors.white,
                                tooltip: 'Добавить место',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (_cashLocations.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.add_location_alt_rounded,
                                  size: 28,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Нет дополнительных мест',
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Например: в сейфе, в банке и т.д.',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Builder(
                            builder: (context) {
                              final visibleLocations = _cashLocations.asMap().entries
                                  .where((entry) => _showHiddenFunds || !entry.value.isHidden)
                                  .toList();

                              if (visibleLocations.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.add_location_alt_rounded,
                                        size: 28,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Нет дополнительных мест',
                                        style: TextStyle(
                                          color: Colors.grey.shade800,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Например: в сейфе, в банке и т.д.',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return SizedBox(
                                height: 200,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: visibleLocations.length,
                                  itemBuilder: (context, visibleIndex) {
                                    final entry = visibleLocations[visibleIndex];
                                    final actualIndex = entry.key;
                                    final location = entry.value;
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        right: visibleIndex < visibleLocations.length - 1 ? 12 : 0,
                                      ),
                                      child: SizedBox(
                                        width: 340,
                                        child: _CashLocationForm(
                                          locationInput: location,
                                          onRemove: () => _removeCashLocation(actualIndex),
                                          index: actualIndex,
                                          isTemporarilyVisible: location.isHidden && _showHiddenFunds,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 20),

                        // Bank Cards Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: _SectionHeader(
                                icon: Icons.credit_card_rounded,
                                title: 'Банковские карты',
                                color: Colors.blue.shade600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.deepPurple.shade400,
                                    Colors.deepPurple.shade600,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.deepPurple.shade200,
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: _addBankCard,
                                icon: const Icon(Icons.add_rounded),
                                color: Colors.white,
                                tooltip: 'Добавить карту',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Cards List
                        if (_bankCards.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.credit_card_off_rounded,
                                  size: 28,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Нет добавленных карт',
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Нажмите + чтобы добавить карту',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Builder(
                            builder: (context) {
                              final visibleCards = _bankCards.asMap().entries
                                  .where((entry) => _showHiddenFunds || !entry.value.isHidden)
                                  .toList();

                              if (visibleCards.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.credit_card_off_rounded,
                                        size: 28,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Нет добавленных карт',
                                        style: TextStyle(
                                          color: Colors.grey.shade800,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Нажмите + чтобы добавить карту',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return SizedBox(
                                height: 200,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: visibleCards.length,
                                  itemBuilder: (context, visibleIndex) {
                                    final entry = visibleCards[visibleIndex];
                                    final actualIndex = entry.key;
                                    final card = entry.value;
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        right: visibleIndex < visibleCards.length - 1 ? 12 : 0,
                                      ),
                                      child: SizedBox(
                                        width: 340,
                                        child: _ModernBankCardForm(
                                          cardInput: card,
                                          onRemove: () => _removeBankCard(actualIndex),
                                          index: actualIndex,
                                          isTemporarilyVisible: card.isHidden && _showHiddenFunds,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 20),

                        // Mobile Wallets Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: _SectionHeader(
                                icon: Icons.phone_android_rounded,
                                title: 'Мобильные кошельки',
                                color: Colors.teal.shade600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.teal.shade400,
                                    Colors.teal.shade600,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.teal.shade200,
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: _addMobileWallet,
                                icon: const Icon(Icons.add_rounded),
                                color: Colors.white,
                                tooltip: 'Добавить кошелек',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Wallets List
                        if (_mobileWallets.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.phonelink_off_rounded,
                                  size: 28,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Нет мобильных кошельков',
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Нажмите + чтобы добавить кошелек',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Builder(
                            builder: (context) {
                              final visibleWallets = _mobileWallets.asMap().entries
                                  .where((entry) => _showHiddenFunds || !entry.value.isHidden)
                                  .toList();

                              if (visibleWallets.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.phonelink_off_rounded,
                                        size: 28,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Нет мобильных кошельков',
                                        style: TextStyle(
                                          color: Colors.grey.shade800,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Нажмите + чтобы добавить кошелек',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return SizedBox(
                                height: 200,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: visibleWallets.length,
                                  itemBuilder: (context, visibleIndex) {
                                    final entry = visibleWallets[visibleIndex];
                                    final actualIndex = entry.key;
                                    final wallet = entry.value;
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        right: visibleIndex < visibleWallets.length - 1 ? 12 : 0,
                                      ),
                                      child: SizedBox(
                                        width: 340,
                                        child: _MobileWalletForm(
                                          walletInput: wallet,
                                          onRemove: () => _removeMobileWallet(actualIndex),
                                          index: actualIndex,
                                          isTemporarilyVisible: wallet.isHidden && _showHiddenFunds,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 20),

                        // Save Button
                        Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepPurple.shade400,
                                Colors.deepPurple.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurple.shade200,
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _saveUserData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.white),
                                const SizedBox(width: 12),
                                Text(
                                  _isEditMode ? 'Сохранить изменения' : 'Сохранить и продолжить',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestoreInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isSuccess;

  const _RestoreInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isSuccess ? Colors.green.shade700 : Colors.grey.shade500,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isSuccess ? Colors.green.shade700 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class CashLocationInput {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  bool isHidden = false;

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}

class _CashLocationForm extends StatefulWidget {
  final CashLocationInput locationInput;
  final VoidCallback onRemove;
  final int index;
  final bool isTemporarilyVisible;

  const _CashLocationForm({
    required this.locationInput,
    required this.onRemove,
    required this.index,
    this.isTemporarilyVisible = false,
  });

  @override
  State<_CashLocationForm> createState() => _CashLocationFormState();
}

class _CashLocationFormState extends State<_CashLocationForm> {

  List<IconData> _getLocationIcons() {
    return [
      Icons.home_rounded,
      Icons.account_balance_rounded,
      Icons.business_rounded,
      Icons.savings_rounded,
      Icons.wallet_rounded,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.locationInput.nameController.text.isEmpty
        ? 'Место ${widget.index + 1}'
        : widget.locationInput.nameController.text;
    final amount = double.tryParse(widget.locationInput.amountController.text) ?? 0.0;
    final icon = _getLocationIcons()[widget.index % _getLocationIcons().length];

    return GestureDetector(
      onTap: () => _showEditDialog(),
      child: Container(
        decoration: BoxDecoration(
          gradient: widget.isTemporarilyVisible
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.orange.shade300,
                    Colors.orange.shade500,
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.orange.shade400,
                    Colors.orange.shade600,
                  ],
                ),
          borderRadius: BorderRadius.circular(20),
          border: widget.isTemporarilyVisible
              ? Border.all(
                  color: Colors.orange.shade700,
                  width: 3,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: widget.isTemporarilyVisible
                  ? Colors.orange.shade400.withValues(alpha: 0.7)
                  : Colors.orange.shade300.withValues(alpha: 0.5),
              blurRadius: widget.isTemporarilyVisible ? 20 : 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _showEditDialog(),
                      icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: widget.onRemove,
                      icon: const Icon(Icons.delete_rounded, color: Colors.white, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${amount.toStringAsFixed(2)} ₽',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.orange.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Редактировать место',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () {
                  setDialogState(() {
                    setState(() {
                      widget.locationInput.isHidden = !widget.locationInput.isHidden;
                    });
                  });
                },
                icon: Icon(
                  widget.locationInput.isHidden
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: widget.locationInput.isHidden
                      ? Colors.grey.shade400
                      : Colors.orange.shade600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: widget.locationInput.nameController,
                decoration: InputDecoration(
                  labelText: 'Название места',
                  hintText: 'Например: В сейфе',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: widget.locationInput.amountController,
                decoration: InputDecoration(
                  labelText: 'Сумма',
                  hintText: '0.00',
                  suffixText: '₽',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Отмена'),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.orange.shade600],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {});
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BankCardInput {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController numberController = TextEditingController();
  final TextEditingController balanceController = TextEditingController();
  final TextEditingController bankController = TextEditingController();
  bool isHidden = false;

  void dispose() {
    nameController.dispose();
    numberController.dispose();
    balanceController.dispose();
    bankController.dispose();
  }
}

class MobileWalletInput {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController balanceController = TextEditingController();
  bool isHidden = false;

  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    balanceController.dispose();
  }
}

class _ModernBankCardForm extends StatefulWidget {
  final BankCardInput cardInput;
  final VoidCallback onRemove;
  final int index;
  final bool isTemporarilyVisible;

  const _ModernBankCardForm({
    required this.cardInput,
    required this.onRemove,
    required this.index,
    this.isTemporarilyVisible = false,
  });

  @override
  State<_ModernBankCardForm> createState() => _ModernBankCardFormState();
}

class _ModernBankCardFormState extends State<_ModernBankCardForm> {

  List<List<Color>> _getCardGradients() {
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
    final colors = _getCardGradients()[widget.index % _getCardGradients().length];
    final cardName = widget.cardInput.nameController.text.isEmpty
        ? 'Карта ${widget.index + 1}'
        : widget.cardInput.nameController.text;
    final cardNumber = widget.cardInput.numberController.text.isEmpty
        ? '••••'
        : widget.cardInput.numberController.text;
    final bankName = widget.cardInput.bankController.text.isEmpty
        ? 'Банк'
        : widget.cardInput.bankController.text;
    final balance = double.tryParse(widget.cardInput.balanceController.text) ?? 0.0;

    return GestureDetector(
      onTap: () => _showEditDialog(),
      child: Container(
        decoration: BoxDecoration(
          gradient: widget.isTemporarilyVisible
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
          border: widget.isTemporarilyVisible
              ? Border.all(
                  color: Colors.orange.shade700,
                  width: 3,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: widget.isTemporarilyVisible
                  ? Colors.orange.shade400.withValues(alpha: 0.7)
                  : colors[0].withValues(alpha: 0.4),
              blurRadius: widget.isTemporarilyVisible ? 25 : 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    bankName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _showEditDialog(),
                      icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: widget.onRemove,
                      icon: const Icon(Icons.delete_rounded, color: Colors.white, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•••• $cardNumber',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cardName.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'БАЛАНС',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${balance.toStringAsFixed(2)} ₽',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog() {
    final colors = _getCardGradients()[widget.index % _getCardGradients().length];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.credit_card_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Редактировать карту',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () {
                  setDialogState(() {
                    setState(() {
                      widget.cardInput.isHidden = !widget.cardInput.isHidden;
                    });
                  });
                },
                icon: Icon(
                  widget.cardInput.isHidden
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: widget.cardInput.isHidden
                      ? Colors.grey.shade400
                      : colors[0],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: widget.cardInput.nameController,
                  decoration: InputDecoration(
                    labelText: 'Название карты',
                    hintText: 'Например: Основная карта',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: widget.cardInput.bankController,
                  decoration: InputDecoration(
                    labelText: 'Банк',
                    hintText: 'Например: Сбербанк',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: widget.cardInput.numberController,
                  decoration: InputDecoration(
                    labelText: 'Последние 4 цифры',
                    hintText: '1234',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: widget.cardInput.balanceController,
                  decoration: InputDecoration(
                    labelText: 'Баланс',
                    hintText: '0.00',
                    suffixText: '₽',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Отмена'),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {});
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileWalletForm extends StatefulWidget {
  final MobileWalletInput walletInput;
  final VoidCallback onRemove;
  final int index;
  final bool isTemporarilyVisible;

  const _MobileWalletForm({
    required this.walletInput,
    required this.onRemove,
    required this.index,
    this.isTemporarilyVisible = false,
  });

  @override
  State<_MobileWalletForm> createState() => _MobileWalletFormState();
}

class _MobileWalletFormState extends State<_MobileWalletForm> {

  List<List<Color>> _getWalletGradients() {
    return [
      [const Color(0xFF11998e), const Color(0xFF38ef7d)],
      [const Color(0xFF2193b0), const Color(0xFF6dd5ed)],
      [const Color(0xFFee0979), const Color(0xFFff6a00)],
      [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
      [const Color(0xFFffa751), const Color(0xFFffe259)],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getWalletGradients()[widget.index % _getWalletGradients().length];
    final walletName = widget.walletInput.nameController.text.isEmpty
        ? 'Кошелек ${widget.index + 1}'
        : widget.walletInput.nameController.text;
    final phone = widget.walletInput.phoneController.text.isEmpty
        ? '+7 (•••) •••-••-••'
        : widget.walletInput.phoneController.text;
    final balance = double.tryParse(widget.walletInput.balanceController.text) ?? 0.0;

    return GestureDetector(
      onTap: () => _showEditDialog(),
      child: Container(
        decoration: BoxDecoration(
          gradient: widget.isTemporarilyVisible
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
          border: widget.isTemporarilyVisible
              ? Border.all(
                  color: Colors.orange.shade700,
                  width: 3,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: widget.isTemporarilyVisible
                  ? Colors.orange.shade400.withValues(alpha: 0.7)
                  : colors[0].withValues(alpha: 0.4),
              blurRadius: widget.isTemporarilyVisible ? 25 : 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _showEditDialog(),
                      icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: widget.onRemove,
                      icon: const Icon(Icons.delete_rounded, color: Colors.white, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        walletName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_rounded,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              phone,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'БАЛАНС',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${balance.toStringAsFixed(2)} ₽',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog() {
    final colors = _getWalletGradients()[widget.index % _getWalletGradients().length];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.phone_android_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Редактировать кошелек',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () {
                  setDialogState(() {
                    setState(() {
                      widget.walletInput.isHidden = !widget.walletInput.isHidden;
                    });
                  });
                },
                icon: Icon(
                  widget.walletInput.isHidden
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: widget.walletInput.isHidden
                      ? Colors.grey.shade400
                      : colors[0],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: widget.walletInput.nameController,
                decoration: InputDecoration(
                  labelText: 'Название кошелька',
                  hintText: 'Например: Яндекс.Деньги',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: widget.walletInput.phoneController,
                decoration: InputDecoration(
                  labelText: 'Номер телефона',
                  hintText: '+79001234567',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: widget.walletInput.balanceController,
                decoration: InputDecoration(
                  labelText: 'Баланс',
                  hintText: '0.00',
                  suffixText: '₽',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Отмена'),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {});
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

