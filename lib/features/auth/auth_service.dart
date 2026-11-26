import 'package:sqflite/sqflite.dart';
import '../../core/db/app_database.dart';
import '../../core/security/password_hasher.dart';

enum LoginStatus { ok, badCredentials, locked, suspended }

class LoginResult {
  LoginResult(this.status, {this.user, this.lockedUntil, this.remainingAttempts});
  final LoginStatus status;
  final Map<String, Object?>? user;
  final DateTime? lockedUntil;
  final int? remainingAttempts;
  bool get mustChangePassword => (user?['must_change_password'] ?? 0) == 1;
}

class AuthService {
  AuthService(this.app, {PasswordHasher? hasher, DateTime Function()? clock})
      : _hasher = hasher ?? PasswordHasher(),
        _now = clock ?? DateTime.now;

  final AppDatabase app;
  final PasswordHasher _hasher;
  final DateTime Function() _now;

  static const maxAttempts = 5; // محاولات خاطئة متتالية
  static const lockMinutes = 15; // مدة الإيقاف المؤقت

  /// يُنشئ حساب المدير الافتراضي admin/admin مرة واحدة فقط: عند غياب أي مستخدم.
  /// كلمة المرور لا تُكتب في أي ملف إعدادات، وتُخزَّن مجزّأة، ويُجبَر المدير على تغييرها.
  Future<bool> ensureDefaultAdmin() async {
    final n = Sqflite.firstIntValue(await app.db.rawQuery('SELECT COUNT(*) FROM users')) ?? 0;
    if (n > 0) return false;
    final t = nowIso();
    await app.db.insert('users', {
      'id': newId(), 'serial': 1, 'username': 'admin',
      'password_hash': await _hasher.hash('admin'),
      'full_name': 'المدير', 'role': 'manager', 'status': 'active',
      'must_change_password': 1, 'created_at': t, 'updated_at': t,
    });
    await app.securityEvent('admin', 'default_admin_created');
    return true;
  }

  Future<LoginResult> login(String username, String password) async {
    final rows = await app.db.query('users', where: 'username = ?', whereArgs: [username.trim()]);
    if (rows.isEmpty) {
      await app.securityEvent(username, 'login_failed', 'unknown user');
      return LoginResult(LoginStatus.badCredentials);
    }
    final u = rows.first;
    if (u['status'] == 'suspended') {
      await app.securityEvent(username, 'login_blocked', 'suspended');
      return LoginResult(LoginStatus.suspended);
    }
    final lockedUntil = u['locked_until'] == null ? null : DateTime.parse(u['locked_until'] as String);
    if (lockedUntil != null && lockedUntil.isAfter(_now().toUtc())) {
      await app.securityEvent(username, 'login_blocked', 'account temporarily locked');
      return LoginResult(LoginStatus.locked, lockedUntil: lockedUntil.toLocal());
    }
    if (await _hasher.verify(password, u['password_hash'] as String)) {
      await app.db.update('users', {'failed_attempts': 0, 'locked_until': null},
          where: 'id = ?', whereArgs: [u['id']]);
      await app.securityEvent(username, 'login_ok');
      return LoginResult(LoginStatus.ok, user: u);
    }
    final fails = ((u['failed_attempts'] as int?) ?? 0) + 1;
    if (fails >= maxAttempts) {
      final until = _now().toUtc().add(const Duration(minutes: lockMinutes));
      await app.db.update('users', {'failed_attempts': 0, 'locked_until': until.toIso8601String()},
          where: 'id = ?', whereArgs: [u['id']]);
      await app.securityEvent(username, 'account_locked', 'until ${until.toIso8601String()}');
      return LoginResult(LoginStatus.locked, lockedUntil: until.toLocal());
    }
    await app.db.update('users', {'failed_attempts': fails}, where: 'id = ?', whereArgs: [u['id']]);
    await app.securityEvent(username, 'login_failed', 'attempt $fails');
    return LoginResult(LoginStatus.badCredentials, remainingAttempts: maxAttempts - fails);
  }

  /// تغيير كلمة المرور: يتطلب الحالية، ويتحقق من السياسة، ويرفع علم الإجبار.
  /// يرجع null عند النجاح أو رسالة خطأ بالعربية.
  Future<String?> changePassword(String userId, String current, String next) async {
    final rows = await app.db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (rows.isEmpty) return 'الحساب غير موجود';
    final u = rows.first;
    if (!await _hasher.verify(current, u['password_hash'] as String)) {
      return 'كلمة المرور الحالية غير صحيحة';
    }
    final err = PasswordPolicy.validate(next, username: u['username'] as String);
    if (err != null) return err;
    if (await _hasher.verify(next, u['password_hash'] as String)) {
      return 'كلمة المرور الجديدة يجب أن تختلف عن الحالية';
    }
    await app.db.update(
      'users',
      {'password_hash': await _hasher.hash(next), 'must_change_password': 0, 'updated_at': nowIso()},
      where: 'id = ?', whereArgs: [userId],
    );
    await app.audit(userId, 'users', 'change_password');
    await app.securityEvent(u['username'] as String, 'password_changed');
    return null;
  }

  /// المدير فقط (يتحقق منه المستدعي): إعادة تفعيل حساب مقفل.
  Future<void> unlock(String userId, String byUserId) async {
    await app.db.update('users', {'failed_attempts': 0, 'locked_until': null},
        where: 'id = ?', whereArgs: [userId]);
    await app.audit(byUserId, 'users', 'unlock', userId);
  }
}
