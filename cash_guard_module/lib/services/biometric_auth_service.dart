import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  static final BiometricAuthService _instance = BiometricAuthService._internal();
  factory BiometricAuthService() => _instance;
  BiometricAuthService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> canUseBiometrics() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics ||
          await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  Future<bool> authenticate({String reason = 'Подтвердите вход с помощью биометрии'}) async {
    try {
      final bool canAuth = await canUseBiometrics();
      if (!canAuth) return false;

      final List<BiometricType> availableBiometrics = await getAvailableBiometrics();
      if (availableBiometrics.isEmpty) return false;

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      return didAuthenticate;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getBiometricErrorMessage() async {
    final canAuth = await canUseBiometrics();
    if (!canAuth) {
      return 'Биометрия недоступна на этом устройстве';
    }

    final availableBiometrics = await getAvailableBiometrics();
    if (availableBiometrics.isEmpty) {
      return 'Биометрия не настроена на устройстве';
    }

    return null;
  }
}