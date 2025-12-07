import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../models/debt.dart';
import '../models/user.dart' show User;
import '../models/transaction.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // ========== НАСТРОЙКИ БИОМЕТРИИ ==========

  /// Включить/отключить биометрическую аутентификацию
  Future<void> setBiometricEnabled(bool enabled) async {
    await _secureStorage.write(
      key: 'biometric_enabled',
      value: enabled.toString(),
    );
  }

  /// Проверить, включена ли биометрическая аутентификация
  Future<bool> getBiometricEnabled() async {
    final value = await _secureStorage.read(key: 'biometric_enabled');
    return value == 'true';
  }

  // ========== НАСТРОЙКИ ТЕМЫ ==========

  /// Установить режим темы ('light', 'dark', 'system')
  Future<void> setThemeMode(String mode) async {
    await _secureStorage.write(key: 'theme_mode', value: mode);
  }

  /// Получить текущий режим темы
  Future<String> getThemeMode() async {
    final mode = await _secureStorage.read(key: 'theme_mode');
    return mode ?? 'system'; // По умолчанию системная тема
  }

  // ========== РАБОТА С ПАРОЛЕМ ==========

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  Future<void> setPassword(String password) async {
    final hashedPassword = _hashPassword(password);
    await _secureStorage.write(key: 'user_password', value: hashedPassword);
  }

  Future<bool> checkPassword(String password) async {
    final storedHash = await _secureStorage.read(key: 'user_password');
    if (storedHash == null) return false;
    final inputHash = _hashPassword(password);
    return storedHash == inputHash;
  }

  Future<bool> isPasswordSet() async {
    final password = await _secureStorage.read(key: 'user_password');
    return password != null;
  }

  Future<void> deletePassword() async {
    await _secureStorage.delete(key: 'user_password');
  }

  // ========== РАБОТА С ДАННЫМИ ПОЛЬЗОВАТЕЛЯ ==========

  Future<void> saveUserData(User user) async {
    final jsonString = jsonEncode(user.toJson());
    await _secureStorage.write(key: 'user_data', value: jsonString);
  }

  Future<User?> getUserData() async {
    final jsonString = await _secureStorage.read(key: 'user_data');
    if (jsonString == null) return null;
    final json = jsonDecode(jsonString);
    return User.fromJson(json);
  }

  Future<bool> isUserDataSet() async {
    final userData = await _secureStorage.read(key: 'user_data');
    return userData != null;
  }

  Future<void> deleteUserData() async {
    await _secureStorage.delete(key: 'user_data');
  }

  // ========== РАБОТА С ТРАНЗАКЦИЯМИ ==========

  Future<void> saveTransactions(List<Transaction> transactions) async {
    final jsonString = jsonEncode(
      transactions.map((t) => t.toJson()).toList(),
    );
    await _secureStorage.write(key: 'transactions', value: jsonString);
  }

  Future<List<Transaction>> getTransactions() async {
    final jsonString = await _secureStorage.read(key: 'transactions');
    if (jsonString == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => Transaction.fromJson(json)).toList();
  }

  Future<void> addTransaction(Transaction transaction) async {
    final transactions = await getTransactions();
    transactions.add(transaction);
    await saveTransactions(transactions);
  }

  Future<void> deleteTransaction(String id) async {
    final transactions = await getTransactions();
    transactions.removeWhere((t) => t.id == id);
    await saveTransactions(transactions);
  }

  Future<void> cancelTransaction(String id) async {
    final transactions = await getTransactions();
    final index = transactions.indexWhere((t) => t.id == id);

    if (index != -1) {
      transactions[index] = transactions[index].copyWith(
        status: TransactionStatus.cancelled,
      );
      await saveTransactions(transactions);
    }
  }

  // ========== РАБОТА С НАЧАЛЬНЫМ БАЛАНСОМ ==========

  Future<void> saveInitialBalance(double balance) async {
    await _secureStorage.write(
      key: 'initial_balance',
      value: balance.toString(),
    );
  }

  Future<double> getInitialBalance() async {
    final balance = await _secureStorage.read(key: 'initial_balance');
    if (balance == null) return 0;
    return double.tryParse(balance) ?? 0;
  }

  // ========== РАБОТА С ДОЛГАМИ ==========

  Future<void> saveDebts(List<Debt> debts) async {
    final jsonString = jsonEncode(
      debts.map((d) => d.toJson()).toList(),
    );
    await _secureStorage.write(key: 'debts', value: jsonString);
  }

  Future<List<Debt>> getDebts() async {
    final jsonString = await _secureStorage.read(key: 'debts');
    if (jsonString == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => Debt.fromJson(json)).toList();
  }

  Future<void> addDebt(Debt debt) async {
    final debts = await getDebts();
    debts.add(debt);
    await saveDebts(debts);
  }

  Future<void> updateDebt(Debt debt) async {
    final debts = await getDebts();
    final index = debts.indexWhere((d) => d.id == debt.id);
    if (index != -1) {
      debts[index] = debt;
      await saveDebts(debts);
    }
  }

  Future<void> deleteDebt(String id) async {
    final debts = await getDebts();
    debts.removeWhere((d) => d.id == id);
    await saveDebts(debts);
  }

  // ========== РАБОТА СО СНИМКАМИ СТАТИСТИКИ ==========

  // Месячные снимки
  Future<Map<String, dynamic>> getMonthlySnapshots() async {
    final jsonString = await _secureStorage.read(key: 'monthly_snapshots');
    if (jsonString == null) return {};
    return Map<String, dynamic>.from(jsonDecode(jsonString));
  }

  Future<void> saveMonthlySnapshot(String key, Map<String, dynamic> snapshot) async {
    final snapshots = await getMonthlySnapshots();
    snapshots[key] = snapshot;
    await _secureStorage.write(
      key: 'monthly_snapshots',
      value: jsonEncode(snapshots),
    );
  }

  // Годовые снимки
  Future<Map<String, dynamic>> getYearlySnapshots() async {
    final jsonString = await _secureStorage.read(key: 'yearly_snapshots');
    if (jsonString == null) return {};
    return Map<String, dynamic>.from(jsonDecode(jsonString));
  }

  Future<void> saveYearlySnapshot(String key, Map<String, dynamic> snapshot) async {
    final snapshots = await getYearlySnapshots();
    snapshots[key] = snapshot;
    await _secureStorage.write(
      key: 'yearly_snapshots',
      value: jsonEncode(snapshots),
    );
  }

  // ========== ОЧИСТКА ВСЕХ ДАННЫХ ==========

  Future<void> clearAllData() async {
    await _secureStorage.deleteAll();
  }
}