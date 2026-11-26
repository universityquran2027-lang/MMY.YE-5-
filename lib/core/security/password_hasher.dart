import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

/// تجزئة PBKDF2-HMAC-SHA256 مع salt عشوائي لكل كلمة مرور.
/// الصيغة المخزنة: pbkdf2$<iterations>$<saltB64>$<hashB64>
/// (الملح والتكرارات داخل النص تسمح بترقية عدد التكرارات مستقبلاً.)
class PasswordHasher {
  PasswordHasher({this.iterations = 210000});
  final int iterations;

  Future<String> hash(String password) async {
    final rnd = Random.secure();
    final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
    final h = await _derive(password, salt, iterations);
    return 'pbkdf2\$$iterations\$${base64.encode(salt)}\$${base64.encode(h)}';
  }

  Future<bool> verify(String password, String stored) async {
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != 'pbkdf2') return false;
    final iters = int.tryParse(parts[1]);
    if (iters == null) return false;
    final salt = base64.decode(parts[2]);
    final expected = base64.decode(parts[3]);
    final actual = await _derive(password, salt, iters);
    // مقارنة بزمن ثابت
    if (actual.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }

  Future<List<int>> _derive(String pw, List<int> salt, int iters) async {
    final algo = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iters, bits: 256);
    final key = await algo.deriveKeyFromPassword(password: pw, nonce: salt);
    return key.extractBytes();
  }
}

/// سياسة كلمة المرور المعتمدة: 8 خانات على الأقل، حروف وأرقام.
class PasswordPolicy {
  static String? validate(String pw, {String? username}) {
    if (pw.length < 8) return 'كلمة المرور يجب ألا تقل عن 8 خانات';
    if (!RegExp(r'\p{L}', unicode: true).hasMatch(pw)) return 'يجب أن تحتوي على حروف';
    if (!RegExp(r'\d').hasMatch(pw)) return 'يجب أن تحتوي على أرقام';
    if (pw.toLowerCase() == 'admin' || (username != null && pw.toLowerCase() == username.toLowerCase())) {
      return 'لا يسمح باستخدام كلمة المرور الافتراضية أو اسم المستخدم';
    }
    return null;
  }
}
