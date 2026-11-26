import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

enum BiometricKind { none, face, fingerprint, other }

/// دخول بيومتري حقيقي عبر واجهات النظام الرسمية:
/// Android: البصمة / الوجه عبر BiometricPrompt ، Windows: Windows Hello.
/// لا تُخزَّن أي بيانات بصمة؛ نخزّن فقط علم «مفعّل لهذا المستخدم» في التخزين الآمن للنظام
/// (Android Keystore / Windows Credential Locker).
class BiometricService {
  BiometricService({LocalAuthentication? auth, FlutterSecureStorage? storage})
      : _auth = auth ?? LocalAuthentication(),
        _store = storage ?? const FlutterSecureStorage();
  final LocalAuthentication _auth;
  final FlutterSecureStorage _store;

  String _key(String userId) => 'bio_enabled_$userId';

  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  Future<BiometricKind> kind() async {
    try {
      final t = await _auth.getAvailableBiometrics();
      if (t.contains(BiometricType.face)) return BiometricKind.face;
      if (t.contains(BiometricType.fingerprint)) return BiometricKind.fingerprint;
      return t.isEmpty ? BiometricKind.none : BiometricKind.other;
    } on PlatformException {
      return BiometricKind.none;
    }
  }

  Future<bool> isEnabledFor(String userId) async =>
      (await _store.read(key: _key(userId))) == '1';

  /// يُستدعى فقط بعد أن يكون المستخدم قد سجّل دخوله بكلمة المرور.
  Future<bool> enable(String userId) async {
    if (!await isSupported()) return false;
    if (!await _authenticate('فعّل الدخول بالبصمة')) return false;
    await _store.write(key: _key(userId), value: '1');
    return true;
  }

  Future<void> disable(String userId) => _store.delete(key: _key(userId));

  Future<bool> authenticate() => _authenticate('سجّل الدخول إلى النظام');

  Future<bool> _authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } on PlatformException {
      return false; // يسقط المستخدم تلقائياً إلى كلمة المرور
    }
  }
}
