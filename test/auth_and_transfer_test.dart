import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mmy_ye/core/db/app_database.dart';
import 'package:mmy_ye/core/security/password_hasher.dart';
import 'package:mmy_ye/features/auth/auth_service.dart';
import 'package:mmy_ye/features/transfer/mmy_package.dart';

Future<AppDatabase> _db(String name) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final d = await Directory.systemTemp.createTemp(name);
  return AppDatabase.open(overridePath: d.path);
}

void main() {
  late AppDatabase a, b;
  setUp(() async {
    a = await _db('mmy_a');
    b = await _db('mmy_b');
  });
  tearDown(() async { await a.close(); await b.close(); });

  group('الحسابات', () {
    test('admin الافتراضي مرة واحدة ويُجبَر على التغيير', () async {
      final auth = AuthService(a, hasher: PasswordHasher(iterations: 1000));
      expect(await auth.ensureDefaultAdmin(), isTrue);
      expect(await auth.ensureDefaultAdmin(), isFalse);
      final r = await auth.login('admin', 'admin');
      expect(r.status, LoginStatus.ok);
      expect(r.mustChangePassword, isTrue);
      expect(await auth.changePassword(r.user!['id'] as String, 'admin', 'admin'), isNotNull);
      expect(await auth.changePassword(r.user!['id'] as String, 'admin', 'Strong123'), isNull);
      expect((await auth.login('admin', 'Strong123')).mustChangePassword, isFalse);
      expect((await auth.login('admin', 'admin')).status, LoginStatus.badCredentials);
    });
    test('إيقاف مؤقت بعد 5 محاولات خاطئة', () async {
      final auth = AuthService(a, hasher: PasswordHasher(iterations: 1000));
      await auth.ensureDefaultAdmin();
      for (var i = 0; i < 5; i++) { await auth.login('admin', 'wrong$i'); }
      expect((await auth.login('admin', 'admin')).status, LoginStatus.locked);
    });
    test('لا يمكن إنشاء حساب رابع/مكرر المنصب', () async {
      final auth = AuthService(a, hasher: PasswordHasher(iterations: 1000));
      await auth.ensureDefaultAdmin();
      expect(
        () => a.db.insert('users', {
          'id': newId(), 'username': 'x', 'password_hash': 'h', 'role': 'manager',
          'created_at': nowIso(), 'updated_at': nowIso()}),
        throwsA(anything),
      );
    });
  });

  group('التصدير والاستيراد', () {
    Future<void> seedCenter(AppDatabase d, String id, String name, String ts) =>
        d.db.insert('centers', {'id': id, 'name': name, 'status': 'active', 'created_at': ts, 'updated_at': ts});

    test('ذهاب وإياب كامل دون فقدان', () async {
      await seedCenter(a, 'c1', 'مركز أ', '2026-01-01T00:00:00Z');
      final f = await MmyPackage(a).export(targetDir: a.dir.path);
      final rep = await MmyPackage(b).import(f);
      expect(rep.ok, isTrue);
      expect(rep.inserted['centers'], 1);
      expect((await b.db.query('centers')).single['name'], 'مركز أ');
      expect(rep.backupPath, isNotNull);
    });
    test('تكرار وتعارض: المحلي يُحفظ افتراضياً ولا يُحذف شيء', () async {
      await seedCenter(a, 'c1', 'من الآيباد', '2026-02-01T00:00:00Z');
      await seedCenter(b, 'c1', 'من الكمبيوتر', '2026-01-01T00:00:00Z');
      await seedCenter(b, 'c2', 'موجود فقط هنا', '2026-01-01T00:00:00Z');
      final f = await MmyPackage(a).export(targetDir: a.dir.path);
      final rep = await MmyPackage(b).import(f);
      expect(rep.conflicts['centers'], 1);
      final names = (await b.db.query('centers', orderBy: 'id')).map((e) => e['name']).toList();
      expect(names, ['من الكمبيوتر', 'موجود فقط هنا']);
      final rep2 = await MmyPackage(b).import(f, policy: ConflictPolicy.keepNewer);
      expect((await b.db.query('centers', where: "id='c1'")).single['name'], 'من الآيباد');
      expect(rep2.ok, isTrue);
    });
    test('التشفير: عبارة صحيحة وخاطئة', () async {
      await seedCenter(a, 'c1', 'مركز', '2026-01-01T00:00:00Z');
      final f = await MmyPackage(a).export(targetDir: a.dir.path, passphrase: 'pass-12345');
      expect(() => MmyPackage(b).inspect(f), throwsFormatException);
      expect(() => MmyPackage(b).inspect(f, passphrase: 'wrong'), throwsFormatException);
      final s = await MmyPackage(b).inspect(f, passphrase: 'pass-12345');
      expect(s.tables['centers'], 1);
    });
    test('ملف معبوث به يُرفض قبل أي تعديل', () async {
      await seedCenter(a, 'c1', 'مركز', '2026-01-01T00:00:00Z');
      final f = await MmyPackage(a).export(targetDir: a.dir.path);
      final bytes = await f.readAsBytes();
      bytes[bytes.length ~/ 2] ^= 0xFF;
      await f.writeAsBytes(bytes);
      expect(() => MmyPackage(b).import(f), throwsA(anything));
      expect(await b.db.query('centers'), isEmpty);
    });
  });
}
