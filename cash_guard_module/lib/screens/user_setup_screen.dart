import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/secure_storage_service.dart';
import 'home_screen.dart';
import '../models/user.dart';

class UserSetupScreen extends StatefulWidget {
  const UserSetupScreen({super.key});

  @override
  State<UserSetupScreen> createState() => _UserSetupScreenState();
}

class _UserSetupScreenState extends State<UserSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cashInHandController = TextEditingController();
  final _storageService = SecureStorageService();

  final List<BankCardInput> _bankCards = [];

  @override
  void dispose() {
    _nameController.dispose();
    _cashInHandController.dispose();
    for (var card in _bankCards) {
      card.dispose();
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

  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = User(
      name: _nameController.text.trim(),
      cashInHand: double.tryParse(_cashInHandController.text) ?? 0,
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

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройка профиля'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text(
              'Давайте настроим ваш финансовый профиль',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Эти данные помогут вам отслеживать свои финансы',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),

            // Имя пользователя
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Ваше имя',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Пожалуйста, введите ваше имя';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Наличные
            TextFormField(
              controller: _cashInHandController,
              decoration: InputDecoration(
                labelText: 'Наличные (в руках/собираю)',
                prefixIcon: const Icon(Icons.attach_money),
                suffixText: '₽',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 24),

            // Банковские карты
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Банковские карты',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _addBankCard,
                  icon: const Icon(Icons.add),
                  tooltip: 'Добавить карту',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Список карт
            if (_bankCards.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.credit_card_off,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Нет добавленных карт',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Нажмите + чтобы добавить',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_bankCards.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _BankCardForm(
                    cardInput: _bankCards[index],
                    onRemove: () => _removeBankCard(index),
                    index: index,
                  ),
                );
              }),

            const SizedBox(height: 24),

            // Кнопка сохранения
            ElevatedButton(
              onPressed: _saveUserData,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Сохранить и продолжить',
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
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

  void dispose() {
    nameController.dispose();
    numberController.dispose();
    balanceController.dispose();
    bankController.dispose();
  }
}

class _BankCardForm extends StatelessWidget {
  final BankCardInput cardInput;
  final VoidCallback onRemove;
  final int index;

  const _BankCardForm({
    required this.cardInput,
    required this.onRemove,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Карта ${index + 1}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                  tooltip: 'Удалить карту',
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: cardInput.nameController,
              decoration: InputDecoration(
                labelText: 'Название карты',
                hintText: 'Например: Основная карта',
                prefixIcon: const Icon(Icons.label),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              controller: cardInput.bankController,
              decoration: InputDecoration(
                labelText: 'Название банка (необязательно)',
                hintText: 'Например: Сбербанк',
                prefixIcon: const Icon(Icons.account_balance),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: cardInput.numberController,
              decoration: InputDecoration(
                labelText: 'Последние 4 цифры карты',
                hintText: '1234',
                prefixIcon: const Icon(Icons.credit_card),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите последние 4 цифры';
                }
                if (value.length != 4) {
                  return 'Должно быть 4 цифры';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: cardInput.balanceController,
              decoration: InputDecoration(
                labelText: 'Баланс на карте',
                prefixIcon: const Icon(Icons.account_balance_wallet),
                suffixText: '₽',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите баланс (можно 0)';
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
    );
  }
}