import 'package:flutter_test/flutter_test.dart';
import 'package:mmy_ye/core/security/password_hasher.dart';

void main() {
  final h = PasswordHasher(iterations: 1000); // قليل للسرعة في الاختبار فقط
  test('hash/verify صحيح وخاطئ', () async {
    final s = await h.hash('Secret123');
    expect(s.startsWith(r'pbkdf2$1000$'), isTrue);
    expect(s.contains('Secret123'), isFalse);
    expect(await h.verify('Secret123', s), isTrue);
    expect(await h.verify('secret123', s), isFalse);
  });
  test('ملح مختلف لكل تجزئة', () async {
    expect(await h.hash('Secret123') == await h.hash('Secret123'), isFalse);
  });
  test('سياسة كلمة المرور', () {
    expect(PasswordPolicy.validate('abc123'), isNotNull); // قصيرة
    expect(PasswordPolicy.validate('abcdefgh'), isNotNull); // بلا أرقام
    expect(PasswordPolicy.validate('12345678'), isNotNull); // بلا حروف
    expect(PasswordPolicy.validate('Abcdef12'), isNull);
    expect(PasswordPolicy.validate('كلمةسر12'), isNull);
  });
}
