import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../models/user.dart' show User;

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

  Future<void> clearAllData() async {
    await _secureStorage.deleteAll();
  }
}