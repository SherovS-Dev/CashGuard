import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import '../services/secure_storage_service.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _storageService = SecureStorageService();

  TransactionType _selectedType = TransactionType.income;
  TransactionLocation? _selectedLocation;
  TransactionLocation? _selectedTransferTo;

  List<TransactionLocation> _availableLocations = [];
  bool _isLoadingLocations = true;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    final user = await _storageService.getUserData();
    if (user == null) return;

    final locations = <TransactionLocation>[];

    // Добавляем все места хранения наличных
    for (var cashLocation in user.cashLocations) {
      locations.add(
        TransactionLocation(
          type: LocationType.cash,
          name: cashLocation.name,
          id: cashLocation.id,
        ),
      );
    }

    // Добавляем все банковские карты
    for (var card in user.bankCards) {
      locations.add(
        TransactionLocation(
          type: LocationType.card,
          name: card.bankName != null
              ? '${card.bankName} •${card.cardNumber.substring(card.cardNumber.length - 4)}'
              : '${card.cardName} •${card.cardNumber.substring(card.cardNumber.length - 4)}',
          id: card.cardNumber,
        ),
      );
    }

    // Добавляем мобильные кошельки
    for (var wallet in user.mobileWallets) {
      locations.add(
        TransactionLocation(
          type: LocationType.mobileWallet,
          name: wallet.name,
          id: wallet.id,
        ),
      );
    }

    setState(() {
      _availableLocations = locations;
      _isLoadingLocations = false;
      if (locations.isNotEmpty) {
        _selectedLocation = locations.first;
      }
    });
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, выберите место'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedType == TransactionType.transfer && _selectedTransferTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, выберите место назначения'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedType == TransactionType.transfer &&
        _selectedLocation?.id == _selectedTransferTo?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нельзя перевести на то же самое место'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final transaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      description: _descriptionController.text.trim(),
      amount: double.parse(_amountController.text),
      type: _selectedType,
      date: DateTime.now(),
      location: _selectedLocation!,
      transferTo: _selectedTransferTo,
    );

    // Обновляем баланс пользователя
    final user = await _storageService.getUserData();
    if (user != null) {
      User updatedUser = user;

      if (_selectedType == TransactionType.transfer) {
        // Обработка перевода
        updatedUser = _processTransfer(updatedUser, transaction);
      } else {
        // Обработка дохода или расхода
        updatedUser = _processIncomeOrExpense(updatedUser, transaction);
      }

      await _storageService.saveUserData(updatedUser);
    }

    // Сохраняем транзакцию
    await _storageService.addTransaction(transaction);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  User _processTransfer(User user, Transaction transaction) {
    User updatedUser = user;

    // Снимаем с источника
    updatedUser = _updateBalance(updatedUser, transaction.location, -transaction.amount);

    // Зачисляем на получателя
    updatedUser = _updateBalance(updatedUser, transaction.transferTo!, transaction.amount);

    return updatedUser;
  }

  User _processIncomeOrExpense(User user, Transaction transaction) {
    final amountChange = transaction.type == TransactionType.income
        ? transaction.amount
        : -transaction.amount;

    return _updateBalance(user, transaction.location, amountChange);
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
        final updatedCards = user.bankCards.map((card) {
          if (card.cardNumber == location.id) {
            return BankCard(
              cardName: card.cardName,
              cardNumber: card.cardNumber,
              balance: card.balance + amountChange,
              bankName: card.bankName,
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
          if (wallet.id == location.id) {
            return MobileWallet(
              id: wallet.id,
              name: wallet.name,
              bankName: wallet.bankName,
              balance: wallet.balance + amountChange,
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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocations) {
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
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_circle_rounded,
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
                            'Новая транзакция',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Добавьте доход, расход или перевод',
                            style: TextStyle(
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
                                label: 'Доход',
                                icon: Icons.arrow_downward_rounded,
                                color: Colors.green,
                                isSelected: _selectedType == TransactionType.income,
                                onTap: () {
                                  setState(() {
                                    _selectedType = TransactionType.income;
                                    _selectedTransferTo = null;
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              child: _TypeButton(
                                label: 'Расход',
                                icon: Icons.arrow_upward_rounded,
                                color: Colors.red,
                                isSelected: _selectedType == TransactionType.expense,
                                onTap: () {
                                  setState(() {
                                    _selectedType = TransactionType.expense;
                                    _selectedTransferTo = null;
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              child: _TypeButton(
                                label: 'Перевод',
                                icon: Icons.swap_horiz_rounded,
                                color: Colors.blue,
                                isSelected: _selectedType == TransactionType.transfer,
                                onTap: () {
                                  setState(() {
                                    _selectedType = TransactionType.transfer;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Amount Field
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
                        child: TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Сумма',
                            hintText: '0.00',
                            prefixIcon: Icon(
                              Icons.attach_money_rounded,
                              color: _selectedType == TransactionType.income
                                  ? Colors.green
                                  : _selectedType == TransactionType.transfer
                                  ? Colors.blue
                                  : Colors.red,
                              size: 32,
                            ),
                            suffixText: '₽',
                            suffixStyle: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _selectedType == TransactionType.income
                                  ? Colors.green
                                  : _selectedType == TransactionType.transfer
                                  ? Colors.blue
                                  : Colors.red,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.all(20),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Введите сумму';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Введите корректную сумму';
                            }
                            if (double.parse(value) <= 0) {
                              return 'Сумма должна быть больше 0';
                            }
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Description Field
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
                        child: TextFormField(
                          controller: _descriptionController,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Описание',
                            hintText: _selectedType == TransactionType.transfer
                                ? 'Например: Пополнение карты'
                                : 'Например: Зарплата за октябрь',
                            prefixIcon: Icon(
                              Icons.description_rounded,
                              color: Colors.deepPurple.shade400,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.all(20),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Введите описание';
                            }
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Location Selector
                      Text(
                        _selectedType == TransactionType.transfer ? 'Откуда' : 'Место',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
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
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableLocations.map((location) {
                            final isSelected = _selectedLocation?.id == location.id;
                            return ChoiceChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getLocationIcon(location.type),
                                    size: 18,
                                    color: isSelected
                                        ? Colors.deepPurple.shade700
                                        : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(location.name),
                                ],
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedLocation = selected ? location : null;
                                });
                              },
                              backgroundColor: Colors.grey.shade50,
                              selectedColor: Colors.deepPurple.shade100,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.deepPurple.shade700
                                    : Colors.grey.shade700,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.deepPurple.shade300
                                    : Colors.grey.shade300,
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      // Transfer To Selector (only for transfers)
                      if (_selectedType == TransactionType.transfer) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Куда',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
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
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableLocations.map((location) {
                              final isSelected = _selectedTransferTo?.id == location.id;
                              return ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getLocationIcon(location.type),
                                      size: 18,
                                      color: isSelected
                                          ? Colors.blue.shade700
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(location.name),
                                  ],
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedTransferTo = selected ? location : null;
                                  });
                                },
                                backgroundColor: Colors.grey.shade50,
                                selectedColor: Colors.blue.shade100,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.blue.shade700
                                      : Colors.grey.shade700,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                side: BorderSide(
                                  color: isSelected
                                      ? Colors.blue.shade300
                                      : Colors.grey.shade300,
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],

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
                          onPressed: _saveTransaction,
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
                              Icon(Icons.check_circle_rounded, color: Colors.white),
                              SizedBox(width: 12),
                              Text(
                                'Сохранить транзакцию',
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
                      const SizedBox(height: 24),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}