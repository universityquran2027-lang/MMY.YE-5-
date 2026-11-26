import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mmy_ye/core/db/app_database.dart';
import 'package:mmy_ye/core/permissions.dart';
import 'package:mmy_ye/features/centers/centers_repository.dart';
import 'package:mmy_ye/features/staff/staff_repository.dart';

void main() {
  late AppDatabase app;
  late CentersRepository centers;
  late StaffRepository staff;

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final d = await Directory.systemTemp.createTemp('mmy_cs');
    app = await AppDatabase.open(overridePath: d.path);
    centers = CentersRepository(app, 'u1');
    staff = StaffRepository(app, 'u1');
  });
  tearDown(() => app.close());

  test('ترقيم تلقائي وتعديل المركز يحفظ المعرّف', () async {
    final a = await centers.save({'name': 'أ', 'status': 'active'});
    final b = await centers.save({'name': 'ب', 'status': 'active'});
    expect((await centers.byId(a))!['serial'], 1);
    expect((await centers.byId(b))!['serial'], 2);
    await centers.save({'name': 'أ معدل', 'status': 'active'}, id: a);
    expect((await centers.byId(a))!['name'], 'أ معدل');
    expect((await centers.list(q: 'معدل')).length, 1);
  });

  test('إعلامي يُضاف من المركز يظهر في القائمة العامة وعدّاد المركز', () async {
    final c = await centers.save({'name': 'مركز', 'status': 'active'});
    await staff.save({'full_name': 'علي', 'center_id': c, 'status': 'active'});
    expect((await staff.list(q: 'علي')).single['center_name'], 'مركز');
    expect((await centers.list()).single['staff_count'], 1);
  });

  test('لا يُحذف مركز أو إعلامي مرتبط بسجلات', () async {
    final c = await centers.save({'name': 'مركز', 'status': 'active'});
    final s = await staff.save({'full_name': 'علي', 'center_id': c, 'status': 'active'});
    expect(await centers.delete(c), isNotNull);
    expect(await staff.delete(s), isNull); // إيقاف مع الاحتفاظ بالسجل
    expect((await staff.byId(s))!['status'], 'stopped');
    expect(await centers.delete(c), isNotNull); // الإعلامي محفوظ ومرتبط بالمركز
  });

  test('إعلامي مرتبط بمهمة لا يُحذف', () async {
    final c = await centers.save({'name': 'مركز', 'status': 'active'});
    final s = await staff.save({'full_name': 'علي', 'center_id': c, 'status': 'active'});
    final t = nowIso();
    await app.db.insert('field_tasks', {'id': 't1', 'title': 'مهمة', 'task_type': 'تغطية',
        'center_id': c, 'supervisor_staff_id': s, 'created_at': t, 'updated_at': t});
    await app.db.insert('task_staff', {'id': 'ts1', 'task_id': 't1', 'staff_id': s, 'updated_at': t});
    expect(await staff.delete(s), isNull); // الإيقاف يحافظ على ارتباط المهمة
    expect((await staff.byId(s))!['status'], 'stopped');
    expect((await staff.tasksOf(s)).single['title'], 'مهمة');
  });

  test('صلاحيات الأدوار', () {
    expect(Role.manager.canEditOperations, isTrue);
    expect(Role.assistant.canEditOperations, isTrue);
    expect(Role.archivist.canEditOperations, isFalse);
    expect(Role.assistant.canManageAccounts, isFalse);
  });
}
