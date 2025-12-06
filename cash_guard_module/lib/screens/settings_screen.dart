import 'package:flutter/material.dart';
import '../services/secure_storage_service.dart';
import '../services/biometric_auth_service.dart';
import '../constants/app_theme.dart';
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
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }

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
          backgroundColor: value ? AppColors.accentGreen : AppColors.accentOrange,
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
  }

  Future<void> _resetPassword() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: AppColors.cardBackground,
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: AppColors.accentOrange),
            const SizedBox(width: 12),
            Text(
              'Сбросить пароль?',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        content: Text(
          'Это удалит ваш текущий пароль и все финансовые данные. Вы уверены?',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Отмена', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentRed,
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
            builder: (context) => LockScreen(onThemeChanged: widget.onThemeChanged),
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
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Настройки',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
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
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),

          // Биометрия
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: _biometricEnabled,
                  onChanged: _biometricAvailable ? _toggleBiometric : null,
                  title: Text(
                    'Вход по биометрии',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _biometricAvailable
                        ? 'Используйте отпечаток или Face ID для входа'
                        : 'Биометрия недоступна на устройстве',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.fingerprint_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Внешний вид
          const _SectionHeader(
            icon: Icons.palette_rounded,
            title: 'Внешний вид',
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _ThemeTile(
                  icon: Icons.light_mode_rounded,
                  title: 'Светлая тема',
                  isSelected: _themeMode == 'light',
                  onTap: () => _changeTheme('light'),
                ),
                Divider(height: 1, color: AppColors.border),
                _ThemeTile(
                  icon: Icons.dark_mode_rounded,
                  title: 'Темная тема',
                  isSelected: _themeMode == 'dark',
                  onTap: () => _changeTheme('dark'),
                ),
                Divider(height: 1, color: AppColors.border),
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
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.backup_rounded,
                      color: AppColors.accentBlue,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    'Backup & Restore',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Резервное копирование',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: AppColors.textMuted,
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
            color: AppColors.accentRed,
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.3)),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.accentRed,
                  size: 24,
                ),
              ),
              title: const Text(
                'Сбросить все данные',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentRed,
                ),
              ),
              subtitle: Text(
                'Удалить пароль и все данные',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.accentRed.withValues(alpha: 0.5),
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
                  color: AppColors.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 12),
                Text(
                  'CashGuard',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Версия 1.0.0',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Защита ваших финансов',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
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
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
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
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.textMuted.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isSelected ? AppColors.primary : AppColors.textMuted,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      trailing: isSelected
          ? const Icon(
        Icons.check_circle_rounded,
        color: AppColors.primary,
        size: 24,
      )
          : null,
      onTap: onTap,
    );
  }
}
