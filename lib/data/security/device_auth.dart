import 'dart:io';

import 'package:local_auth/local_auth.dart';

import '../../domain/security/device_authenticator.dart';

class DeviceAuth implements DeviceAuthenticator {
  final _auth = LocalAuthentication();
  @override
  Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported() &&
          (Platform.isWindows ||
              (await _auth.getAvailableBiometrics()).isNotEmpty);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate() => _auth.authenticate(
    localizedReason: 'Подтвердите вход в Delta',
    biometricOnly: !Platform.isWindows,
    persistAcrossBackgrounding: false,
  );
}
