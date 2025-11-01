import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

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

  // Работа с паролем
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  Future<void> setPassword(String password) async {
    final hashedPassword = _hashPassword(password);
    await _secureStorage.write(key: 'user_password', value: hashedPassword);
  }

  Future<bool> verifyPassword(String password) async {
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

  // Работа с данными пользователя
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

  // Работа с транзакциями
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

  // Работа с начальным балансом
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

  Future<void> clearAllData() async {
    await _secureStorage.deleteAll();
  }
}