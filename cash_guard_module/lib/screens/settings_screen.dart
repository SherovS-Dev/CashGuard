import 'package:flutter/material.dart';
import '../services/secure_storage_service.dart';
import '../services/biometric_auth_service.dart';
import 'backup_screen.dart';
import 'lock_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Function(ThemeMode)? onThemeChanged;

  const SettingsScreen({super.key, this.onThemeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storageService = SecureStorageService();
  final _biometricService = BiometricAuthService();

  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String _themeMode = 'system';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final biometricAvailable = await _biometricService.canUseBiometrics();
    final biometricEnabled = await _storageService.getBiometricEnabled();
    final themeMode = await _storageService.getThemeMode();

    setState(() {
      _biometricAvailable = biometricAvailable;
      _biometricEnabled = biometricEnabled;
      _themeMode = themeMode;
      _isLoading = false;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    if (!_biometricAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Биометрия недоступна на этом устройстве'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Просто включаем/выключаем без требования аутентификации
    await _storageService.setBiometricEnabled(value);
    setState(() {
      _biometricEnabled = value;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                value ? Icons.check_circle : Icons.info_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value
                      ? 'Биометрия включена. Теперь вы можете использовать её для входа'
                      : 'Биометрия отключена',
                ),
              ),
            ],
          ),
          backgroundColor: value ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _changeTheme(String mode) async {
    await _storageService.setThemeMode(mode);
    setState(() {
      _themeMode = mode;
    });

    // Применяем тему
    ThemeMode themeMode;
    switch (mode) {
      case 'light':
        themeMode = ThemeMode.light;
        break;
      case 'dark':
        themeMode = ThemeMode.dark;
        break;
      default:
        themeMode = ThemeMode.system;
    }

    // Вызываем callback для изменения темы
    widget.onThemeChanged?.call(themeMode);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.palette, color: Colors.white),
              const SizedBox(width: 12),
              Text('Тема изменена: ${_getThemeName(mode)}'),
            ],
          ),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  String _getThemeName(String mode) {
    switch (mode) {
      case 'light':
        return 'Светлая';
      case 'dark':
        return 'Темная';
      case 'system':
        return 'Системная';
      default:
        return 'Системная';
    }
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
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const LockScreen(),
          ),
              (route) => false,
        );
      }
    }
  }

  void _openBackup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BackupScreen(),
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

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.deepPurple.shade600,
        title: const Text(
          'Настройки',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Безопасность
          const _SectionHeader(
            icon: Icons.security_rounded,
            title: 'Безопасность',
          ),
          const SizedBox(height: 12),

          // Биометрия
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: _biometricEnabled,
                  onChanged: _biometricAvailable ? _toggleBiometric : null,
                  title: const Text(
                    'Вход по биометрии',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _biometricAvailable
                        ? 'Используйте отпечаток или Face ID для входа'
                        : 'Биометрия недоступна на устройстве',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.fingerprint_rounded,
                      color: Colors.deepPurple.shade600,
                      size: 24,
                    ),
                  ),
                  activeColor: Colors.deepPurple.shade600,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Внешний вид
          const _SectionHeader(
            icon: Icons.palette_rounded,
            title: 'Внешний вид',
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _ThemeTile(
                  icon: Icons.light_mode_rounded,
                  title: 'Светлая тема',
                  isSelected: _themeMode == 'light',
                  onTap: () => _changeTheme('light'),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                _ThemeTile(
                  icon: Icons.dark_mode_rounded,
                  title: 'Темная тема',
                  isSelected: _themeMode == 'dark',
                  onTap: () => _changeTheme('dark'),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                _ThemeTile(
                  icon: Icons.brightness_auto_rounded,
                  title: 'Системная тема',
                  isSelected: _themeMode == 'system',
                  onTap: () => _changeTheme('system'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Данные
          const _SectionHeader(
            icon: Icons.storage_rounded,
            title: 'Данные',
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.backup_rounded,
                      color: Colors.blue.shade600,
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Backup & Restore',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Резервное копирование',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                  onTap: _openBackup,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Опасная зона
          const _SectionHeader(
            icon: Icons.warning_rounded,
            title: 'Опасная зона',
            color: Colors.red,
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red.shade600,
                  size: 24,
                ),
              ),
              title: const Text(
                'Сбросить все данные',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
              subtitle: Text(
                'Удалить пароль и все данные',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.red.shade400,
              ),
              onTap: _resetPassword,
            ),
          ),

          const SizedBox(height: 24),

          // О приложении
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.shield_rounded,
                  size: 48,
                  color: Colors.deepPurple.shade300,
                ),
                const SizedBox(height: 12),
                const Text(
                  'CashGuard',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Версия 1.0.0',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Защита ваших финансов',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Colors.deepPurple.shade600;

    return Row(
      children: [
        Icon(icon, color: effectiveColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: effectiveColor,
          ),
        ),
      ],
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.deepPurple.shade50
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isSelected
              ? Colors.deepPurple.shade600
              : Colors.grey.shade600,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? Colors.deepPurple.shade600 : Colors.black87,
        ),
      ),
      trailing: isSelected
          ? Icon(
        Icons.check_circle_rounded,
        color: Colors.deepPurple.shade600,
        size: 24,
      )
          : null,
      onTap: onTap,
    );
  }
}