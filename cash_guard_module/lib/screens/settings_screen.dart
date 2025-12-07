import 'package:flutter/material.dart';
import '../services/secure_storage_service.dart';
import '../services/biometric_auth_service.dart';
import '../constants/app_theme.dart';
import '../main.dart';
import '../utils/page_transitions.dart';
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
  bool _hasEnrolledBiometrics = false;
  String _themeMode = 'system';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final biometricAvailable = await _biometricService.canUseBiometrics();
    final hasEnrolledBiometrics = await _biometricService.hasEnrolledBiometrics();
    final biometricEnabled = await _storageService.getBiometricEnabled();
    final themeMode = await _storageService.getThemeMode();

    setState(() {
      _biometricAvailable = biometricAvailable;
      _hasEnrolledBiometrics = hasEnrolledBiometrics;
      _biometricEnabled = biometricEnabled;
      _themeMode = themeMode;
      _isLoading = false;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value && !_hasEnrolledBiometrics) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Сначала зарегистрируйте биометрические данные в настройках вашего устройства.'),
              ),
            ],
          ),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }

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

    ThemeMode themeMode;
    switch (mode) {
      case 'light':
        themeMode = ThemeMode.light;
        AppColors.setDarkMode(false);
        break;
      case 'dark':
        themeMode = ThemeMode.dark;
        AppColors.setDarkMode(true);
        break;
      default:
        themeMode = ThemeMode.system;
        final brightness = MediaQuery.of(context).platformBrightness;
        AppColors.setDarkMode(brightness == Brightness.dark);
    }

    // Use global app key to change theme immediately
    final appState = context.findAncestorStateOfType<CashGuardAppState>();
    appState?.setThemeMode(themeMode);

    widget.onThemeChanged?.call(themeMode);

    setState(() {
      _themeMode = mode;
    });
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
          InstantPageRoute(page: LockScreen(onThemeChanged: widget.onThemeChanged)),
          (route) => false,
        );
      }
    }
  }

  Future<void> _openBackup() async {
    final enteredPassword = await showDialog<String>(
      context: context,
      builder: (context) => const _PasswordPromptDialog(),
    );

    if (enteredPassword != null) {
      final isCorrect = await _storageService.checkPassword(enteredPassword);
      if (isCorrect && mounted) {
        Navigator.of(context).push(
          FastPageRoute(page: const BackupScreen()),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Неверный пароль'),
            backgroundColor: AppColors.accentRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = AnimatedThemeColors.of(context);

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
            color: themeColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: themeColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader(
            icon: Icons.security_rounded,
            title: 'Безопасность',
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: themeColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: themeColors.border),
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
                      color: themeColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    !_biometricAvailable
                        ? 'Биометрия недоступна на устройстве'
                        : !_hasEnrolledBiometrics
                        ? 'Биометрия не зарегистрирована'
                        : 'Используйте отпечаток или Face ID для входа',
                    style: TextStyle(
                      fontSize: 13,
                      color: themeColors.textSecondary,
                    ),
                  ),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(25),
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
          const _SectionHeader(
            icon: Icons.palette_rounded,
            title: 'Внешний вид',
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: themeColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: themeColors.border),
            ),
            child: Column(
              children: [
                _ThemeTile(
                  icon: Icons.light_mode_rounded,
                  title: 'Светлая тема',
                  isSelected: _themeMode == 'light',
                  onTap: () => _changeTheme('light'),
                  themeColors: themeColors,
                ),
                Divider(height: 1, color: themeColors.border),
                _ThemeTile(
                  icon: Icons.dark_mode_rounded,
                  title: 'Темная тема',
                  isSelected: _themeMode == 'dark',
                  onTap: () => _changeTheme('dark'),
                  themeColors: themeColors,
                ),
                Divider(height: 1, color: themeColors.border),
                _ThemeTile(
                  icon: Icons.brightness_auto_rounded,
                  title: 'Системная тема',
                  isSelected: _themeMode == 'system',
                  onTap: () => _changeTheme('system'),
                  themeColors: themeColors,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(
            icon: Icons.storage_rounded,
            title: 'Данные',
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: themeColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: themeColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withAlpha(25),
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
                      color: themeColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Резервное копирование',
                    style: TextStyle(
                      fontSize: 13,
                      color: themeColors.textSecondary,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: themeColors.textMuted,
                  ),
                  onTap: _openBackup,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(
            icon: Icons.warning_rounded,
            title: 'Опасная зона',
            color: AppColors.accentRed,
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: themeColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accentRed.withAlpha(76)),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentRed.withAlpha(25),
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
                  color: themeColors.textSecondary,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.accentRed.withAlpha(128),
              ),
              onTap: _resetPassword,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.shield_rounded,
                  size: 48,
                  color: AppColors.primary.withAlpha(178),
                ),
                const SizedBox(height: 12),
                Text(
                  'CashGuard',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: themeColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Версия 3.0.0',
                  style: TextStyle(
                    fontSize: 13,
                    color: themeColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Защита ваших финансов',
                  style: TextStyle(
                    fontSize: 12,
                    color: themeColors.textMuted,
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
  final AnimatedThemeColorsData themeColors;

  const _ThemeTile({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
    required this.themeColors,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withAlpha(25)
              : themeColors.textMuted.withAlpha(25),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isSelected ? AppColors.primary : themeColors.textMuted,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? AppColors.primary : themeColors.textPrimary,
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

class _PasswordPromptDialog extends StatefulWidget {
  const _PasswordPromptDialog();

  @override
  State<_PasswordPromptDialog> createState() => _PasswordPromptDialogState();
}

class _PasswordPromptDialogState extends State<_PasswordPromptDialog> {
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    final themeColors = AnimatedThemeColors.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: themeColors.cardBackground,
      title: Text('Введите пароль', style: TextStyle(color: themeColors.textPrimary)),
      content: TextField(
        controller: _passwordController,
        obscureText: !_isPasswordVisible,
        autofocus: true,
        style: TextStyle(color: themeColors.textPrimary),
        decoration: InputDecoration(
          labelText: 'Пароль',
          labelStyle: TextStyle(color: themeColors.textSecondary),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: themeColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
              color: themeColors.textSecondary,
            ),
            onPressed: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Отмена', style: TextStyle(color: themeColors.textSecondary)),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(_passwordController.text);
          },
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Подтвердить'),
        ),
      ],
    );
  }
}
