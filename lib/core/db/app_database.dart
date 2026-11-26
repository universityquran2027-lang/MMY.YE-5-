import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'schema.dart';

String nowIso() => DateTime.now().toUtc().toIso8601String();
String newId() => const Uuid().v4();

class AppDatabase {
  AppDatabase._(this.db, this.dir);
  final Database db;
  final Directory dir; // مجلد بيانات التطبيق (قاعدة + مرفقات + نسخ احتياطية)

  Directory get attachmentsDir => Directory(p.join(dir.path, 'attachments'));
  Directory get backupsDir => Directory(p.join(dir.path, 'backups'));

  static Future<AppDatabase> open({String? overridePath}) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dir = overridePath != null
        ? Directory(overridePath)
        : await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final db = await openDatabase(
      p.join(dir.path, 'mmy.db'),
      version: kSchemaVersion,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, v) async {
        final b = d.batch();
        for (final s in kCreateStatements) {
          b.execute(s);
        }
        await b.commit(noResult: true);
        await _seed(d);
      },
      onUpgrade: _migrate,
    );
    final a = AppDatabase._(db, dir);
    await a.attachmentsDir.create(recursive: true);
    await a.backupsDir.create(recursive: true);
    return a;
  }


  /// ترحيل تزايدي يحافظ على بيانات الإصدار السابق ولا يعيد إنشاء القاعدة.
  static Future<void> _migrate(Database d, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      Future<void> addColumn(String table, String column, String definition) async {
        final cols = await d.rawQuery('PRAGMA table_info($table)');
        if (!cols.any((c) => c['name'] == column)) {
          await d.execute('ALTER TABLE $table ADD COLUMN $column $definition');
        }
      }
      await addColumn('inventory_items', 'is_active', 'INTEGER NOT NULL DEFAULT 1');
      await addColumn('inventory_moves', 'notes', 'TEXT');
      await addColumn('center_equipment', 'received_at', 'TEXT');
      await addColumn('center_equipment', 'notes', 'TEXT');
      await addColumn('maintenance', 'source_type', "TEXT NOT NULL DEFAULT 'center'");
      await addColumn('maintenance', 'fault_type', 'TEXT');
      await addColumn('maintenance', 'assigned_to', 'TEXT');
      await addColumn('maintenance', 'started_at', 'TEXT');
      await addColumn('maintenance', 'completed_at', 'TEXT');
      await addColumn('delivered_materials', 'rejection_reason', 'TEXT');
      await d.execute("UPDATE maintenance SET source_type = CASE WHEN center_id IS NULL THEN 'warehouse' ELSE 'center' END");
      // إعادة إنشاء جدول التسليم لتغيير القيمة الافتراضية إلى (غير محدد بعد المراجعة)، مع حفظ السجلات.
      await d.execute('ALTER TABLE delivered_materials RENAME TO delivered_materials_v1');
      await d.execute('''CREATE TABLE delivered_materials(
        id TEXT PRIMARY KEY, center_id TEXT NOT NULL REFERENCES centers(id),
        name TEXT NOT NULL, delivered_at TEXT, size_value REAL NOT NULL,
        size_unit TEXT NOT NULL CHECK(size_unit IN ('MB','GB')),
        accepted INTEGER CHECK(accepted IN (0,1)), rejection_reason TEXT,
        updated_at TEXT NOT NULL)''');
      await d.execute('''INSERT INTO delivered_materials
        (id, center_id, name, delivered_at, size_value, size_unit, accepted, rejection_reason, updated_at)
        SELECT id, center_id, name, delivered_at, size_value, size_unit, accepted, rejection_reason, updated_at
        FROM delivered_materials_v1''');
      await d.execute('DROP TABLE delivered_materials_v1');
      Future<void> uniqueIndex(String name, String table, String column) async {
        final duplicates = await d.rawQuery('SELECT $column FROM $table GROUP BY $column HAVING COUNT(*) > 1 LIMIT 1');
        if (duplicates.isEmpty) await d.execute('CREATE UNIQUE INDEX IF NOT EXISTS $name ON $table($column)');
      }
      await uniqueIndex('uq_centers_name', 'centers', 'name');
      await uniqueIndex('uq_staff_serial', 'media_staff', 'serial');
      await uniqueIndex('uq_staff_full_name', 'media_staff', 'full_name');
      await uniqueIndex('uq_inventory_serial', 'inventory_items', 'serial');
      await uniqueIndex('uq_inventory_name', 'inventory_items', 'name');
      await uniqueIndex('uq_admin_profile_user', 'admin_profiles', 'user_id');
      await uniqueIndex('uq_evaluation_criteria_name', 'evaluation_criteria', 'name');
      await d.execute("CREATE TRIGGER IF NOT EXISTS audit_log_no_update BEFORE UPDATE ON audit_log BEGIN SELECT RAISE(ABORT, 'audit_log is immutable'); END");
      await d.execute("CREATE TRIGGER IF NOT EXISTS audit_log_no_delete BEFORE DELETE ON audit_log BEGIN SELECT RAISE(ABORT, 'audit_log is immutable'); END");
      await d.execute("CREATE TRIGGER IF NOT EXISTS security_log_no_update BEFORE UPDATE ON security_log BEGIN SELECT RAISE(ABORT, 'security_log is immutable'); END");
      await d.execute("CREATE TRIGGER IF NOT EXISTS security_log_no_delete BEFORE DELETE ON security_log BEGIN SELECT RAISE(ABORT, 'security_log is immutable'); END");
      await d.execute("CREATE TRIGGER IF NOT EXISTS task_supervisor_center_insert BEFORE INSERT ON field_tasks WHEN NEW.supervisor_staff_id IS NULL OR NOT EXISTS (SELECT 1 FROM media_staff s WHERE s.id=NEW.supervisor_staff_id AND s.center_id=NEW.center_id) BEGIN SELECT RAISE(ABORT, 'مشرف المهمة يجب أن يكون تابعاً لمركز المهمة'); END");
      await d.execute("CREATE TRIGGER IF NOT EXISTS task_supervisor_center_update BEFORE UPDATE OF supervisor_staff_id, center_id ON field_tasks WHEN NEW.supervisor_staff_id IS NULL OR NOT EXISTS (SELECT 1 FROM media_staff s WHERE s.id=NEW.supervisor_staff_id AND s.center_id=NEW.center_id) BEGIN SELECT RAISE(ABORT, 'مشرف المهمة يجب أن يكون تابعاً لمركز المهمة'); END");
      await d.execute("CREATE TRIGGER IF NOT EXISTS staff_supervisor_center_guard BEFORE UPDATE OF center_id ON media_staff WHEN EXISTS (SELECT 1 FROM field_tasks t WHERE t.supervisor_staff_id=OLD.id AND t.center_id<>NEW.center_id) BEGIN SELECT RAISE(ABORT, 'لا يمكن نقل الإعلامي؛ فهو مشرف على مهام في مركزه الحالي'); END");
      await d.execute("CREATE TRIGGER IF NOT EXISTS staff_center_required_insert BEFORE INSERT ON media_staff WHEN NEW.center_id IS NULL BEGIN SELECT RAISE(ABORT, 'يجب ربط الإعلامي بمركز'); END");
      await d.execute("CREATE TRIGGER IF NOT EXISTS staff_center_required_update BEFORE UPDATE OF center_id ON media_staff WHEN NEW.center_id IS NULL BEGIN SELECT RAISE(ABORT, 'يجب ربط الإعلامي بمركز'); END");
      await d.execute("CREATE TRIGGER IF NOT EXISTS maintenance_source_valid_insert BEFORE INSERT ON maintenance WHEN (NEW.source_type='warehouse' AND NEW.center_id IS NOT NULL) OR (NEW.source_type='center' AND NEW.center_id IS NULL) BEGIN SELECT RAISE(ABORT, 'مصدر الصيانة غير صالح'); END");
      await d.execute("CREATE TRIGGER IF NOT EXISTS maintenance_source_valid_update BEFORE UPDATE OF source_type, center_id ON maintenance WHEN (NEW.source_type='warehouse' AND NEW.center_id IS NOT NULL) OR (NEW.source_type='center' AND NEW.center_id IS NULL) BEGIN SELECT RAISE(ABORT, 'مصدر الصيانة غير صالح'); END");
      await d.execute("CREATE TRIGGER IF NOT EXISTS maintenance_status_valid_insert BEFORE INSERT ON maintenance WHEN NEW.status NOT IN ('open','inspection','repairing','completed','cancelled') BEGIN SELECT RAISE(ABORT, 'حالة الصيانة غير صالحة'); END");
      await d.execute("CREATE TRIGGER IF NOT EXISTS maintenance_status_valid_update BEFORE UPDATE OF status ON maintenance WHEN NEW.status NOT IN ('open','inspection','repairing','completed','cancelled') BEGIN SELECT RAISE(ABORT, 'حالة الصيانة غير صالحة'); END");
      await d.execute("CREATE TRIGGER IF NOT EXISTS evaluation_revision_no_update BEFORE UPDATE ON evaluation_revisions BEGIN SELECT RAISE(ABORT, 'evaluation_revisions is immutable'); END");
      await d.execute("CREATE TRIGGER IF NOT EXISTS evaluation_revision_no_delete BEFORE DELETE ON evaluation_revisions BEGIN SELECT RAISE(ABORT, 'evaluation_revisions is immutable'); END");
      await d.execute("CREATE TRIGGER IF NOT EXISTS criteria_weight_valid_insert BEFORE INSERT ON evaluation_criteria WHEN NEW.weight <= 0 OR NEW.weight > 100 BEGIN SELECT RAISE(ABORT, 'وزن المعيار يجب أن يكون أكبر من صفر وحتى 100'); END");
      await d.execute("CREATE TRIGGER IF NOT EXISTS criteria_weight_valid_update BEFORE UPDATE OF weight ON evaluation_criteria WHEN NEW.weight <= 0 OR NEW.weight > 100 BEGIN SELECT RAISE(ABORT, 'وزن المعيار يجب أن يكون أكبر من صفر وحتى 100'); END");
      await d.execute("CREATE TRIGGER IF NOT EXISTS criteria_axis_weight_total BEFORE UPDATE OF is_final ON evaluation_criteria WHEN NEW.is_final=1 AND ABS((SELECT COALESCE(SUM(weight),0) FROM evaluation_criteria WHERE axis=NEW.axis)-100.0)>0.01 BEGIN SELECT RAISE(ABORT, 'مجموع أوزان معايير المحور يجب أن يساوي 100'); END");
      await d.execute("CREATE TRIGGER IF NOT EXISTS evaluation_score_valid_insert BEFORE INSERT ON evaluation_scores WHEN NEW.score<0 OR NEW.score>COALESCE((SELECT weight FROM evaluation_criteria WHERE id=NEW.criterion_id),-1) OR ABS(NEW.score*100-ROUND(NEW.score*100))>0.000001 BEGIN SELECT RAISE(ABORT, 'درجة المعيار خارج النطاق أو تتجاوز منزلتين عشريتين'); END");
      await d.execute("CREATE TRIGGER IF NOT EXISTS evaluation_score_valid_update BEFORE UPDATE OF score, criterion_id ON evaluation_scores WHEN NEW.score<0 OR NEW.score>COALESCE((SELECT weight FROM evaluation_criteria WHERE id=NEW.criterion_id),-1) OR ABS(NEW.score*100-ROUND(NEW.score*100))>0.000001 BEGIN SELECT RAISE(ABORT, 'درجة المعيار خارج النطاق أو تتجاوز منزلتين عشريتين'); END");
    }
  }

  /// بيانات أساسية فقط (أنواع المخرجات والمعايير). ليست بيانات تجريبية.
  static Future<void> _seed(Database d) async {
    final t = nowIso();
    const outputs = [
      ['عدد الدروس', 'count'],
      ['عدد التطبيقات', 'count'],
      ['عدد الأفراد الموثقين', 'count'],
      ['تاريخ تسليم المواد', 'date'],
      ['حجم المواد', 'size_mb'],
    ];
    for (final o in outputs) {
      await d.insert('output_types',
          {'id': newId(), 'name': o[0], 'data_type': o[1], 'is_builtin': 1, 'updated_at': t});
    }
    // الأوزان المقترحة في الوثيقة (القسم 9.6) - غير معتمدة نهائياً
    const criteria = [
      ['الأداء العام', 'الالتزام بالمهام', 12.0],
      ['الأداء العام', 'جودة العمل', 12.0],
      ['الأداء العام', 'نشاط الإعلاميين', 8.0],
      ['الأداء العام', 'المحافظة على التجهيزات', 8.0],
      ['الأداء العام', 'الإنجاز الميداني', 8.0],
      ['المواد الإعلامية', 'حجم المواد الموردة', 8.0],
      ['المواد الإعلامية', 'الالتزام بمواعيد التوريد', 4.0],
      ['المواد الإعلامية', 'المواد المقبولة والمرفوضة', 10.0],
      ['التوثيق والإنتاج', 'الأفراد الموثقون', 10.0],
      ['التوثيق والإنتاج', 'الدروس', 10.0],
      ['التوثيق والإنتاج', 'التطبيقات', 10.0],
    ];
    for (var i = 0; i < criteria.length; i++) {
      await d.insert('evaluation_criteria', {
        'id': newId(), 'axis': criteria[i][0], 'name': criteria[i][1],
        'weight': criteria[i][2], 'is_final': 0, 'sort_order': i, 'updated_at': t,
      });
    }
    await d.insert('settings',
        {'key': 'channel_name', 'value': 'الإعلام الحربي اليمني', 'updated_at': t});
  }

  Future<void> audit(String? userId, String section, String action, [String? details]) =>
      db.insert('audit_log', {
        'id': newId(), 'user_id': userId, 'section': section,
        'action': action, 'details': details, 'at': nowIso(),
      });

  Future<void> securityEvent(String? username, String event, [String? details]) =>
      db.insert('security_log', {
        'id': newId(), 'username': username, 'event': event,
        'details': details, 'at': nowIso(),
      });

  Future<void> close() => db.close();
}
