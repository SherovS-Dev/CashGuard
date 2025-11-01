import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../services/secure_storage_service.dart';
import '../models/user.dart';
import '../models/transaction.dart';
import '../models/debt.dart';

class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  final _storageService = SecureStorageService();

  // Создание резервной копии
  Future<Map<String, dynamic>> createBackup() async {
    final user = await _storageService.getUserData();
    final transactions = await _storageService.getTransactions();
    final debts = await _storageService.getDebts();
    final initialBalance = await _storageService.getInitialBalance();

    final backup = {
      'version': '1.0',
      'timestamp': DateTime.now().toIso8601String(),
      'data': {
        'user': user?.toJson(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'debts': debts.map((d) => d.toJson()).toList(),
        'initialBalance': initialBalance,
      },
    };

    return backup;
  }

  // Сохранение backup в файл и отправка через share
  Future<String?> exportBackup() async {
    try {
      final backup = await createBackup();
      final jsonString = const JsonEncoder.withIndent('  ').convert(backup);

      // Получаем временную директорию
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'cashguard_backup_$timestamp.json';
      final file = File('${directory.path}/$fileName');

      // Записываем данные
      await file.writeAsString(jsonString);

      return file.path;
    } catch (e) {
      return null;
    }
  }

  // Поделиться backup файлом
  Future<bool> shareBackup() async {
    try {
      final filePath = await exportBackup();
      if (filePath == null) return false;

      final result = await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'CashGuard Backup',
        text: 'Резервная копия данных CashGuard',
      );

      return result.status == ShareResultStatus.success;
    } catch (e) {
      return false;
    }
  }

  // Сохранить backup в Downloads (Android)
  Future<String?> saveBackupToDownloads() async {
    try {
      final backup = await createBackup();
      final jsonString = const JsonEncoder.withIndent('  ').convert(backup);

      if (Platform.isAndroid) {
        final directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          return null;
        }

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'cashguard_backup_$timestamp.json';
        final file = File('${directory.path}/$fileName');

        await file.writeAsString(jsonString);
        return file.path;
      } else if (Platform.isIOS) {
        // Для iOS используем documents directory
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'cashguard_backup_$timestamp.json';
        final file = File('${directory.path}/$fileName');

        await file.writeAsString(jsonString);
        return file.path;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // Выбрать и восстановить backup файл
  Future<Map<String, dynamic>?> pickAndRestoreBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        return {'success': false, 'error': 'Файл не выбран'};
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final backup = jsonDecode(jsonString) as Map<String, dynamic>;

      return await restoreBackup(backup);
    } catch (e) {
      return {'success': false, 'error': 'Ошибка при чтении файла: $e'};
    }
  }

  // Восстановление из backup
  Future<Map<String, dynamic>> restoreBackup(Map<String, dynamic> backup) async {
    try {
      // Проверка версии
      final version = backup['version'] as String?;
      if (version == null) {
        return {'success': false, 'error': 'Неверный формат файла'};
      }

      final data = backup['data'] as Map<String, dynamic>?;
      if (data == null) {
        return {'success': false, 'error': 'Данные не найдены в файле'};
      }

      // Восстанавливаем пользователя
      if (data['user'] != null) {
        final user = User.fromJson(data['user']);
        await _storageService.saveUserData(user);
      }

      // Восстанавливаем транзакции
      if (data['transactions'] != null) {
        final transactions = (data['transactions'] as List)
            .map((t) => Transaction.fromJson(t))
            .toList();
        await _storageService.saveTransactions(transactions);
      }

      // Восстанавливаем долги
      if (data['debts'] != null) {
        final debts = (data['debts'] as List)
            .map((d) => Debt.fromJson(d))
            .toList();
        await _storageService.saveDebts(debts);
      }

      // Восстанавливаем начальный баланс
      if (data['initialBalance'] != null) {
        final initialBalance = (data['initialBalance'] as num).toDouble();
        await _storageService.saveInitialBalance(initialBalance);
      }

      return {
        'success': true,
        'timestamp': backup['timestamp'],
        'userRestored': data['user'] != null,
        'transactionsCount': (data['transactions'] as List?)?.length ?? 0,
        'debtsCount': (data['debts'] as List?)?.length ?? 0,
      };
    } catch (e) {
      return {'success': false, 'error': 'Ошибка восстановления: $e'};
    }
  }

  // Восстановление из JSON строки
  Future<Map<String, dynamic>> restoreFromJson(String jsonString) async {
    try {
      final backup = jsonDecode(jsonString) as Map<String, dynamic>;
      return await restoreBackup(backup);
    } catch (e) {
      return {'success': false, 'error': 'Ошибка парсинга JSON: $e'};
    }
  }

  // Получить информацию о backup без восстановления
  Map<String, dynamic>? getBackupInfo(String jsonString) {
    try {
      final backup = jsonDecode(jsonString) as Map<String, dynamic>;
      final data = backup['data'] as Map<String, dynamic>?;

      if (data == null) return null;

      return {
        'version': backup['version'],
        'timestamp': backup['timestamp'],
        'hasUser': data['user'] != null,
        'transactionsCount': (data['transactions'] as List?)?.length ?? 0,
        'debtsCount': (data['debts'] as List?)?.length ?? 0,
        'initialBalance': data['initialBalance'],
      };
    } catch (e) {
      return null;
    }
  }
}