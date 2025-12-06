import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/debt.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import '../models/cash_location.dart';
import '../models/bank_card.dart';
import '../models/mobile_wallet.dart';
import '../services/secure_storage_service.dart';

class AddDebtScreen extends StatefulWidget {
  final Debt? debtToEdit;

  const AddDebtScreen({super.key, this.debtToEdit});

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _creditorDebtorController = TextEditingController();
  final _amountController = TextEditingController();
  final _interestRateController = TextEditingController();
  final _notesController = TextEditingController();
  final _storageService = SecureStorageService();

  DebtType _selectedType = DebtType.borrowed;
  DateTime _startDate = DateTime.now();
  DateTime? _dueDate;
  bool _isEditMode = false;

  TransactionLocation? _selectedLocation;
  List<TransactionLocation> _availableLocations = [];
  bool _isLoadingLocations = true;

  @override
  void initState() {
    super.initState();
    _loadLocations();
    if (widget.debtToEdit != null) {
      _isEditMode = true;
      final debt = widget.debtToEdit!;
      _descriptionController.text = debt.description;
      _creditorDebtorController.text = debt.creditorDebtor;
      _amountController.text = debt.totalAmount.toStringAsFixed(2);
      _interestRateController.text = debt.interestRate.toStringAsFixed(2);
      _notesController.text = debt.notes ?? '';
      _selectedType = debt.type;
      _startDate = debt.startDate;
      _dueDate = debt.dueDate;
    }
  }

  Future<void> _loadLocations() async {
    final user = await _storageService.getUserData();
    if (user == null) return;

    final locations = <TransactionLocation>[];

    // Добавляем все места хранения наличных (без учета скрытых)
    for (var cashLocation in user.cashLocations) {
      if (!cashLocation.isHidden) {
        locations.add(
          TransactionLocation(
            type: LocationType.cash,
            name: cashLocation.name,
            id: cashLocation.id,
          ),
        );
      }
    }

    // Добавляем банковские карты (без учета скрытых)
    for (var card in user.bankCards) {
      if (!card.isHidden) {
        final uniqueId = '${card.cardName}|${card.cardNumber.substring(card.cardNumber.length - 4)}';
        locations.add(
          TransactionLocation(
            type: LocationType.card,
            name: card.bankName != null
                ? '${card.bankName} •${card.cardNumber.substring(card.cardNumber.length - 4)}'
                : '${card.cardName} •${card.cardNumber.substring(card.cardNumber.length - 4)}',
            id: uniqueId,
          ),
        );
      }
    }

    // Добавляем мобильные кошельки (без учета скрытых)
    for (var wallet in user.mobileWallets) {
      if (!wallet.isHidden) {
        locations.add(
          TransactionLocation(
            type: LocationType.mobileWallet,
            name: wallet.name,
            id: wallet.phoneNumber,
          ),
        );
      }
    }

    setState(() {
      _availableLocations = locations;
      _isLoadingLocations = false;
      if (locations.isNotEmpty && _selectedLocation == null) {
        _selectedLocation = locations.first;
      }
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _creditorDebtorController.dispose();
    _amountController.dispose();
    _interestRateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _getCreditorDebtorLabel() {
    switch (_selectedType) {
      case DebtType.borrowed:
        return 'От кого взяли';
      case DebtType.lent:
        return 'Кому дали';
      case DebtType.credit:
        return 'Название банка';
    }
  }

  String _getLocationLabel() {
    switch (_selectedType) {
      case DebtType.borrowed:
        return 'Откуда взять деньги'; // Я даю деньги → уменьшается баланс
      case DebtType.lent:
        return 'Куда положить деньги'; // Мне дают деньги → увеличивается баланс
      case DebtType.credit:
        return 'Куда зачислить кредит'; // Я беру кредит → увеличивается баланс
    }
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

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : (_dueDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  Future<void> _saveDebt() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Проверяем выбор источника средств только при добавлении нового долга
    if (!_isEditMode && _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, выберите источник средств'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final debt = Debt(
      id: _isEditMode ? widget.debtToEdit!.id : DateTime.now().millisecondsSinceEpoch.toString(),
      description: _descriptionController.text.trim(),
      creditorDebtor: _creditorDebtorController.text.trim(),
      totalAmount: double.parse(_amountController.text),
      interestRate: double.tryParse(_interestRateController.text) ?? 0,
      type: _selectedType,
      startDate: _startDate,
      dueDate: _dueDate,
      status: _isEditMode ? widget.debtToEdit!.status : DebtStatus.active,
      payments: _isEditMode ? widget.debtToEdit!.payments : [],
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    if (_isEditMode) {
      await _storageService.updateDebt(debt);
    } else {
      // При добавлении нового долга обновляем баланс пользователя
      await _storageService.addDebt(debt);

      final user = await _storageService.getUserData();
      if (user != null && _selectedLocation != null) {
        final amount = double.parse(_amountController.text);
        double amountChange;

        // Логика изменения баланса:
        // - DebtType.borrowed (Мне должны): я даю деньги → УМЕНЬШИТЬ баланс
        // - DebtType.lent (Я должен): мне дают деньги → УВЕЛИЧИТЬ баланс
        // - DebtType.credit (Кредит): я беру кредит → УВЕЛИЧИТЬ баланс
        if (_selectedType == DebtType.borrowed) {
          amountChange = -amount; // Я даю деньги
        } else {
          amountChange = amount; // Мне дают деньги (lent или credit)
        }

        final updatedUser = _updateBalance(user, _selectedLocation!, amountChange);
        await _storageService.saveUserData(updatedUser);
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
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
          child: Column(
            children: [
              // App Bar (extends to status bar)
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 20,
                  left: 20,
                  right: 20,
                  bottom: 20,
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
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditMode ? 'Редактировать долг' : 'Новый долг/кредит',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isEditMode ? 'Измените информацию' : 'Добавьте информацию о долге',
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

              // Form
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Type Selector
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _TypeButton(
                                label: 'Мне должны',
                                icon: Icons.arrow_downward_rounded,
                                color: Colors.green,
                                isSelected: _selectedType == DebtType.borrowed,
                                onTap: () {
                                  setState(() {
                                    _selectedType = DebtType.borrowed;
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              child: _TypeButton(
                                label: 'Я должен',
                                icon: Icons.arrow_upward_rounded,
                                color: Colors.orange,
                                isSelected: _selectedType == DebtType.lent,
                                onTap: () {
                                  setState(() {
                                    _selectedType = DebtType.lent;
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              child: _TypeButton(
                                label: 'Кредит',
                                icon: Icons.account_balance_rounded,
                                color: Colors.red,
                                isSelected: _selectedType == DebtType.credit,
                                onTap: () {
                                  setState(() {
                                    _selectedType = DebtType.credit;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Description
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Описание',
                        hint: 'Например: Долг за ремонт',
                        icon: Icons.description_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Введите описание';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Creditor/Debtor
                      _buildTextField(
                        controller: _creditorDebtorController,
                        label: _getCreditorDebtorLabel(),
                        hint: 'Например: Иван Иванов',
                        icon: Icons.person_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Введите имя';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Amount
                      _buildTextField(
                        controller: _amountController,
                        label: 'Сумма долга',
                        hint: '0.00',
                        icon: Icons.attach_money_rounded,
                        suffix: 'ЅМ',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Введите сумму';
                          }
                          if (double.tryParse(value) == null || double.parse(value) <= 0) {
                            return 'Введите корректную сумму';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Location Selector (только при добавлении нового долга)
                      if (!_isEditMode) ...[
                        Container(
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.account_balance_wallet_rounded,
                                      color: Colors.deepPurple.shade400,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _getLocationLabel(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_isLoadingLocations)
                                const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              else if (_availableLocations.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    'Нет доступных источников средств',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                )
                              else
                                ...(_availableLocations.map((location) {
                                  final isSelected = _selectedLocation?.id == location.id;
                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedLocation = location;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.deepPurple.shade50 : Colors.transparent,
                                        border: Border(
                                          top: BorderSide(
                                            color: Colors.grey.shade200,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _getLocationIcon(location.type),
                                            color: isSelected
                                                ? Colors.deepPurple.shade600
                                                : Colors.grey.shade600,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              location.name,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                color: isSelected
                                                    ? Colors.deepPurple.shade700
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ),
                                          if (isSelected)
                                            Icon(
                                              Icons.check_circle_rounded,
                                              color: Colors.deepPurple.shade600,
                                              size: 20,
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList()),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Interest Rate
                      _buildTextField(
                        controller: _interestRateController,
                        label: 'Процентная ставка (необязательно)',
                        hint: '0',
                        icon: Icons.percent_rounded,
                        suffix: '%',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Dates
                      Row(
                        children: [
                          Expanded(
                            child: _DateSelector(
                              label: 'Дата начала',
                              date: _startDate,
                              onTap: () => _selectDate(context, true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DateSelector(
                              label: 'Срок возврата',
                              date: _dueDate,
                              onTap: () => _selectDate(context, false),
                              isOptional: true,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Notes
                      _buildTextField(
                        controller: _notesController,
                        label: 'Заметки (необязательно)',
                        hint: 'Дополнительная информация',
                        icon: Icons.note_rounded,
                        maxLines: 3,
                      ),

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
                          onPressed: _saveDebt,
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
                                _isEditMode ? 'Сохранить изменения' : 'Добавить долг',
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? suffix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
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
        maxLines: maxLines,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.deepPurple.shade400),
          suffixText: suffix,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final bool isOptional;

  const _DateSelector({
    required this.label,
    required this.date,
    required this.onTap,
    this.isOptional = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.deepPurple.shade400,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  date != null
                      ? '${date!.day}.${date!.month}.${date!.year}'
                      : (isOptional ? 'Не указан' : 'Выберите'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: date != null ? Colors.black87 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}