import 'package:sqflite/sqflite.dart';
import '../../core/db/app_database.dart';
import '../../core/widgets.dart';
import '../centers/centers_repository.dart';

class StaffRepository {
  StaffRepository(this.app, this.userId);
  final AppDatabase app;
  final String userId;

  /// حقول نموذج الإعلامي (وثيقة 6.1: البيانات الشخصية والوظيفية). المركز يُختار من القائمة.
  static List<FieldSpec> formFields(List<Row> centers) => [
        const FieldSpec('full_name', 'الاسم الكامل', required: true),
        const FieldSpec('birth_date', 'تاريخ الميلاد', type: FieldType.date),
        const FieldSpec('phone', 'رقم الجوال', type: FieldType.phone),
        const FieldSpec('governorate', 'المحافظة'),
        const FieldSpec('district', 'المديرية'),
        const FieldSpec('area', 'المنطقة'),
        FieldSpec('center_id', 'المركز التابع له', type: FieldType.dropdown, required: true,
            options: [for (final c in centers) (c['id'] as String, c['name'] as String)]),
        const FieldSpec('specialty', 'التخصص الإعلامي'),
        const FieldSpec('joined_at', 'تاريخ الانضمام', type: FieldType.date),
        const FieldSpec('qualification', 'المؤهل العلمي'),
        const FieldSpec('status', 'الحالة', type: FieldType.dropdown, required: true,
            options: [('active', 'نشط'), ('stopped', 'متوقف')]),
      ];

  Future<List<Row>> list({String q = '', String? centerId, String? status}) {
    final like = '%${q.trim()}%';
    final where = <String>['(s.full_name LIKE ? OR s.specialty LIKE ? OR s.phone LIKE ?)'];
    final args = <Object?>[like, like, like];
    if (centerId != null) { where.add('s.center_id = ?'); args.add(centerId); }
    if (status != null) { where.add('s.status = ?'); args.add(status); }
    return app.db.rawQuery('''
      SELECT s.*, c.name AS center_name FROM media_staff s
      LEFT JOIN centers c ON c.id = s.center_id
      WHERE ${where.join(' AND ')} ORDER BY s.serial''', args);
  }

  Future<Row?> byId(String id) async {
    final r = await app.db.rawQuery('''
      SELECT s.*, c.name AS center_name FROM media_staff s
      LEFT JOIN centers c ON c.id = s.center_id WHERE s.id = ?''', [id]);
    return r.isEmpty ? null : r.first;
  }

  /// أي إعلامي يُضاف (من المركز أو من القسم العام) يُسجَّل مرة واحدة في الجدول نفسه
  /// فيظهر تلقائياً في الموضعين.
  Future<String> save(Row v, {String? id}) async {
    final t = nowIso();
    if (id == null) {
      final next = (Sqflite.firstIntValue(await app.db.rawQuery('SELECT MAX(serial) FROM media_staff')) ?? 0) + 1;
      final newid = newId();
      await app.db.insert('media_staff', {...v, 'id': newid, 'serial': next, 'created_at': t, 'updated_at': t});
      await app.audit(userId, 'media_staff', 'add', v['full_name'] as String?);
      return newid;
    }
    await app.db.update('media_staff', {...v, 'updated_at': t}, where: 'id = ?', whereArgs: [id]);
    await app.audit(userId, 'media_staff', 'edit', v['full_name'] as String?);
    return id;
  }

  /// الإيقاف بدلاً من الحذف للحفاظ على سجل الإعلامي وروابطه التاريخية.
  Future<String?> delete(String id) async {
    await app.db.update('media_staff', {'status': 'stopped', 'updated_at': nowIso()},
        where: 'id = ?', whereArgs: [id]);
    await app.audit(userId, 'media_staff', 'deactivate', id);
    return null;
  }

  // المهام تُسحب تلقائياً من قسم المهام الميدانية (وثيقة 6.1 ثالثاً)
  Future<List<Row>> tasksOf(String staffId) => app.db.rawQuery('''
      SELECT t.title, t.status, t.start_date, c.name AS center_name
      FROM field_tasks t
      LEFT JOIN centers c ON c.id = t.center_id
      WHERE t.id IN (SELECT task_id FROM task_staff WHERE staff_id = ?) OR t.supervisor_staff_id = ?
      ORDER BY t.start_date DESC''', [staffId, staffId]);

  Future<List<Row>> courses(String staffId) => app.db.query('staff_courses',
      where: 'staff_id = ?', whereArgs: [staffId], orderBy: 'obtained_at DESC');
  Future<List<Row>> experiences(String staffId) =>
      app.db.query('staff_experience', where: 'staff_id = ?', whereArgs: [staffId]);

  Future<void> addCourse(String staffId, Row v) async {
    await app.db.insert('staff_courses', {...v, 'id': newId(), 'staff_id': staffId, 'updated_at': nowIso()});
    await app.audit(userId, 'media_staff', 'add_course', staffId);
  }

  Future<void> addExperience(String staffId, Row v) async {
    await app.db.insert('staff_experience', {...v, 'id': newId(), 'staff_id': staffId, 'updated_at': nowIso()});
    await app.audit(userId, 'media_staff', 'add_experience', staffId);
  }

  Future<void> deleteCourse(String id) => app.db.delete('staff_courses', where: 'id = ?', whereArgs: [id]);
  Future<void> deleteExperience(String id) => app.db.delete('staff_experience', where: 'id = ?', whereArgs: [id]);
}
