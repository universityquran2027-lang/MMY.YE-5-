import 'package:sqflite/sqflite.dart';
import '../../core/db/app_database.dart';

typedef Row = Map<String, Object?>;

class CentersRepository {
  CentersRepository(this.app, this.userId);
  final AppDatabase app;
  final String userId;

  Future<List<Row>> list({String q = ''}) {
    final like = '%${q.trim()}%';
    return app.db.rawQuery('''
      SELECT c.*,
        (SELECT COUNT(*) FROM media_staff s WHERE s.center_id = c.id) AS staff_count,
        (SELECT e.total_score FROM evaluations e
           WHERE e.center_id = c.id AND e.total_score IS NOT NULL
           ORDER BY e.year DESC, e.month DESC LIMIT 1) AS last_score
      FROM centers c
      WHERE c.name LIKE ? OR c.governorate LIKE ? OR c.district LIKE ? OR c.area LIKE ?
      ORDER BY c.serial''', [like, like, like, like]);
  }

  Future<List<Row>> all() => app.db.query('centers', orderBy: 'serial');

  Future<Row?> byId(String id) async {
    final r = await app.db.query('centers', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : r.first;
  }

  /// إضافة أو تعديل. التعديل يحدّث السجل نفسه (لا ينسخه) فتنعكس التغييرات في كل الأقسام
  /// المرتبطة بالمعرّف مع بقاء السجلات السابقة.
  Future<String> save(Row v, {String? id}) async {
    final t = nowIso();
    if (id == null) {
      final next = (Sqflite.firstIntValue(await app.db.rawQuery('SELECT MAX(serial) FROM centers')) ?? 0) + 1;
      final newid = newId();
      await app.db.insert('centers', {...v, 'id': newid, 'serial': next, 'created_at': t, 'updated_at': t});
      await app.audit(userId, 'centers', 'add', v['name'] as String?);
      return newid;
    }
    await app.db.update('centers', {...v, 'updated_at': t}, where: 'id = ?', whereArgs: [id]);
    await app.audit(userId, 'centers', 'edit', v['name'] as String?);
    return id;
  }

  /// يرجع null عند النجاح، أو سبب المنع. المركز المرتبط بسجلات لا يُحذف (يُوقَف بدلاً من ذلك).
  Future<String?> delete(String id) async {
    final used = [
      for (final t in ['media_staff', 'field_tasks', 'inventory_moves', 'center_equipment', 'evaluations', 'delivered_materials'])
        Sqflite.firstIntValue(await app.db.rawQuery('SELECT COUNT(*) FROM $t WHERE center_id = ?', [id])) ?? 0
    ].fold<int>(0, (a, b) => a + b);
    if (used > 0) return 'لا يمكن حذف مركز مرتبط بسجلات (إعلاميون أو مهام أو تجهيزات أو تقييمات). غيّر حالته إلى «متوقف» للحفاظ على السجلات.';
    await app.db.delete('centers', where: 'id = ?', whereArgs: [id]);
    await app.audit(userId, 'centers', 'delete', id);
    return null;
  }

  Future<List<Row>> staffOf(String centerId) => app.db.query('media_staff',
      where: 'center_id = ?', whereArgs: [centerId], orderBy: 'serial');

  Future<List<Row>> equipmentOf(String centerId) => app.db.rawQuery('''
      SELECT i.name, ce.quantity, i.condition FROM center_equipment ce
      JOIN inventory_items i ON i.id = ce.item_id
      WHERE ce.center_id = ? AND ce.quantity > 0 ORDER BY i.name''', [centerId]);

  Future<List<Row>> tasksOf(String centerId) => app.db.query('field_tasks',
      where: 'center_id = ?', whereArgs: [centerId], orderBy: 'start_date DESC');
}
