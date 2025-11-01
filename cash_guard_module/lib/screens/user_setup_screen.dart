import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  bool _isLoading = true;
  bool _isEditMode = false;
  bool _isRestoring = false;
  User? _existingUser;

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

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
  }

  Future<void> _loadExistingData() async {
    final user = await _storageService.getUserData();

    if (user != null) {
      setState(() {
        _existingUser = user;
        _isEditMode = true;
        _nameController.text = user.name;
        _cashInHandController.text = user.cashInHand.toString();

        // Загружаем банковские карты
        for (var card in user.bankCards) {
          final cardInput = BankCardInput();
          cardInput.nameController.text = card.cardName;
          cardInput.numberController.text = card.cardNumber;
          cardInput.balanceController.text = card.balance.toString();
          cardInput.bankController.text = card.bankName ?? '';
          _bankCards.add(cardInput);
        }
      });
    }

    setState(() {
      _isLoading = false;
    });
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cashInHandController.dispose();
    _animationController.dispose();
    for (var card in _bankCards) {
      card.dispose();
    }
    for (var location in _cashLocations) {
      location.dispose();
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

    // Собираем основные наличные
    double totalCash = double.tryParse(_cashInHandController.text) ?? 0;

    // Добавляем наличные из дополнительных мест
    for (var location in _cashLocations) {
      totalCash += double.tryParse(location.amountController.text) ?? 0;
    }

    final user = User(
      name: _nameController.text.trim(),
      cashInHand: totalCash,
      bankCards: _bankCards.map((input) {
        return BankCard(
          cardName: input.nameController.text.trim(),
          cardNumber: input.numberController.text.trim(),
          balance: double.tryParse(input.balanceController.text) ?? 0,
          bankName: input.bankController.text.trim().isEmpty
              ? null
              : input.bankController.text.trim(),
        );
      }).toList(),
    );

    await _storageService.saveUserData(user);

    // Если это первая настройка (не редактирование), сохраняем начальный баланс
    if (!_isEditMode) {
      await _storageService.saveInitialBalance(user.totalBalance);
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const HomeScreen(),
      ),
    );
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
              // Custom App Bar
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
                child: Row(
                  children: [
                    if (_isEditMode)
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      )
                    else
                      const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
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
                              fontSize: 22,
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
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Кнопка восстановления (только для нового пользователя)
                        if (!_isEditMode) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.blue.shade600,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.shade200,
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _restoreFromBackup,
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.restore_rounded,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Восстановить данные',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Загрузите резервную копию',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        color: Colors.white.withOpacity(0.7),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'или создайте новый профиль',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Info message for edit mode
                        if (_isEditMode)
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue.shade200,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.blue.shade700,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Вы можете изменить существующие данные или добавить новые места хранения средств',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Personal Info Section
                        _SectionHeader(
                          icon: Icons.account_circle_rounded,
                          title: 'Личная информация',
                          color: Colors.deepPurple.shade600,
                        ),
                        const SizedBox(height: 16),

                        // Name Field
                        _ModernTextField(
                          controller: _nameController,
                          label: 'Ваше имя',
                          hint: 'Например: Иван',
                          icon: Icons.person_outline_rounded,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Пожалуйста, введите ваше имя';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Cash Field
                        _ModernTextField(
                          controller: _cashInHandController,
                          label: 'Наличные (основное место)',
                          hint: '0.00',
                          icon: Icons.payments_rounded,
                          suffix: const Text(
                            '₽',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Введите сумму (можно 0)';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Введите корректную сумму';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 32),

                        // Additional Cash Locations Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: _SectionHeader(
                                icon: Icons.account_balance_wallet_rounded,
                                title: 'Дополнительные места (наличные)',
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
                        const SizedBox(height: 16),

                        if (_cashLocations.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.add_location_alt_rounded,
                                  size: 32,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Нет дополнительных мест',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...List.generate(_cashLocations.length, (index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _CashLocationForm(
                                locationInput: _cashLocations[index],
                                onRemove: () => _removeCashLocation(index),
                                index: index,
                              ),
                            );
                          }),

                        const SizedBox(height: 32),

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
                        const SizedBox(height: 16),

                        // Cards List
                        if (_bankCards.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.credit_card_off_rounded,
                                  size: 64,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Нет добавленных карт',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Нажмите + чтобы добавить карту',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...List.generate(_bankCards.length, (index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _ModernBankCardForm(
                                cardInput: _bankCards[index],
                                onRemove: () => _removeBankCard(index),
                                index: index,
                              ),
                            );
                          }),

                        const SizedBox(height: 32),

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

class _ModernTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _ModernTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.suffix,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.deepPurple.shade400),
          suffix: suffix,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

class CashLocationInput {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}

class _CashLocationForm extends StatelessWidget {
  final CashLocationInput locationInput;
  final VoidCallback onRemove;
  final int index;

  const _CashLocationForm({
    required this.locationInput,
    required this.onRemove,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade300,
            Colors.orange.shade500,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.shade200,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Место ${index + 1}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_rounded),
                color: Colors.white,
                tooltip: 'Удалить',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                TextFormField(
                  controller: locationInput.nameController,
                  decoration: InputDecoration(
                    labelText: 'Название места',
                    hintText: 'Например: В сейфе',
                    prefixIcon: const Icon(Icons.label_rounded, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Введите название';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: locationInput.amountController,
                  decoration: InputDecoration(
                    labelText: 'Сумма',
                    hintText: '0.00',
                    prefixIcon: const Icon(Icons.payments_rounded, size: 20),
                    suffixText: '₽',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите сумму';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Введите корректную сумму';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BankCardInput {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController numberController = TextEditingController();
  final TextEditingController balanceController = TextEditingController();
  final TextEditingController bankController = TextEditingController();

  void dispose() {
    nameController.dispose();
    numberController.dispose();
    balanceController.dispose();
    bankController.dispose();
  }
}

class _ModernBankCardForm extends StatelessWidget {
  final BankCardInput cardInput;
  final VoidCallback onRemove;
  final int index;

  const _ModernBankCardForm({
    required this.cardInput,
    required this.onRemove,
    required this.index,
  });

  List<Color> _getCardGradient(int index) {
    final gradients = [
      [Colors.blue.shade400, Colors.blue.shade700],
      [Colors.purple.shade400, Colors.purple.shade700],
      [Colors.orange.shade400, Colors.orange.shade700],
      [Colors.teal.shade400, Colors.teal.shade700],
      [Colors.pink.shade400, Colors.pink.shade700],
    ];
    return gradients[index % gradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getCardGradient(index);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.credit_card_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Карта ${index + 1}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_rounded),
                  color: Colors.white,
                  tooltip: 'Удалить карту',
                ),
              ],
            ),
          ),

          // Card Form
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                _CardFormField(
                  controller: cardInput.nameController,
                  label: 'Название карты',
                  hint: 'Например: Основная карта',
                  icon: Icons.label_rounded,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Введите название';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _CardFormField(
                  controller: cardInput.bankController,
                  label: 'Банк (необязательно)',
                  hint: 'Например: Сбербанк',
                  icon: Icons.account_balance_rounded,
                ),
                const SizedBox(height: 12),
                _CardFormField(
                  controller: cardInput.numberController,
                  label: 'Последние 4 цифры',
                  hint: '1234',
                  icon: Icons.tag_rounded,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите 4 цифры';
                    }
                    if (value.length != 4) {
                      return 'Должно быть 4 цифры';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _CardFormField(
                  controller: cardInput.balanceController,
                  label: 'Баланс',
                  hint: '0.00',
                  icon: Icons.account_balance_wallet_rounded,
                  suffix: const Text(
                    '₽',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите баланс';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Введите корректную сумму';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _CardFormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.suffix,
    this.keyboardType,
    this.maxLength,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        suffix: suffix,
        counterText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}