/// مخطط قاعدة البيانات المحلية (SQLite) - الإصدار 2.
/// كل الجداول القابلة للنقل تستخدم معرّفاً نصياً UUID وحقل updated_at (ISO-8601 UTC)
/// حتى يمكن دمجها عند الاستيراد دون تعارض أرقام تسلسلية بين الجهازين.
const int kSchemaVersion = 2;

const List<String> kCreateStatements = [
  // ---------- الحسابات (ثلاثة فقط: حساب لكل منصب) ----------
  '''CREATE TABLE users(
    id TEXT PRIMARY KEY,
    serial INTEGER,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    full_name TEXT NOT NULL DEFAULT '',
    role TEXT NOT NULL UNIQUE CHECK(role IN ('manager','assistant','archivist')),
    status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','suspended')),
    must_change_password INTEGER NOT NULL DEFAULT 0,
    failed_attempts INTEGER NOT NULL DEFAULT 0,
    locked_until TEXT,
    photo_attachment_id TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )''',
  '''CREATE TABLE admin_profiles(
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL UNIQUE REFERENCES users(id),
    birth_date TEXT, phone TEXT, address TEXT,
    department TEXT, start_date TEXT, job_status TEXT,
    responsibilities TEXT, courses TEXT, qualifications TEXT, experience TEXT,
    updated_at TEXT NOT NULL
  )''',

  // ---------- المراكز ----------
  '''CREATE TABLE centers(
    id TEXT PRIMARY KEY,
    serial INTEGER UNIQUE,
    name TEXT NOT NULL UNIQUE,
    governorate TEXT, district TEXT, area TEXT, address TEXT,
    phone TEXT, manager_name TEXT, manager_phone TEXT,
    founded_at TEXT,
    status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','stopped')),
    notes TEXT,
    created_at TEXT NOT NULL, updated_at TEXT NOT NULL
  )''',

  // ---------- الكادر الإعلامي ----------
  '''CREATE TABLE media_staff(
    id TEXT PRIMARY KEY,
    serial INTEGER UNIQUE,
    full_name TEXT NOT NULL UNIQUE,
    birth_date TEXT, phone TEXT,
    governorate TEXT, district TEXT, area TEXT,
    center_id TEXT NOT NULL REFERENCES centers(id),
    specialty TEXT, joined_at TEXT,
    status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','stopped')),
    photo_attachment_id TEXT,
    qualification TEXT,
    created_at TEXT NOT NULL, updated_at TEXT NOT NULL
  )''',
  '''CREATE TABLE staff_courses(
    id TEXT PRIMARY KEY,
    staff_id TEXT NOT NULL REFERENCES media_staff(id),
    course_name TEXT NOT NULL, issuer TEXT, obtained_at TEXT,
    updated_at TEXT NOT NULL
  )''',
  '''CREATE TABLE staff_experience(
    id TEXT PRIMARY KEY,
    staff_id TEXT NOT NULL REFERENCES media_staff(id),
    description TEXT NOT NULL, duration TEXT,
    updated_at TEXT NOT NULL
  )''',

  // ---------- المهام الميدانية ----------
  '''CREATE TABLE field_tasks(
    id TEXT PRIMARY KEY,
    serial INTEGER UNIQUE,
    title TEXT NOT NULL,
    task_type TEXT NOT NULL,
    center_id TEXT NOT NULL REFERENCES centers(id),
    supervisor_staff_id TEXT NOT NULL REFERENCES media_staff(id),
    location TEXT,
    start_date TEXT, end_date TEXT,
    description TEXT, notes TEXT,
    status TEXT NOT NULL DEFAULT 'planned' CHECK(status IN ('planned','running','done','cancelled')),
    progress_percent INTEGER NOT NULL DEFAULT 0,
    progress_notes TEXT, actual_start TEXT, actual_end TEXT,
    approved_by TEXT REFERENCES users(id), approved_at TEXT,
    created_by TEXT REFERENCES users(id),
    created_at TEXT NOT NULL, updated_at TEXT NOT NULL
  )''',
  '''CREATE TABLE task_staff(
    id TEXT PRIMARY KEY,
    task_id TEXT NOT NULL REFERENCES field_tasks(id),
    staff_id TEXT NOT NULL REFERENCES media_staff(id),
    updated_at TEXT NOT NULL,
    UNIQUE(task_id, staff_id)
  )''',
  // أنواع المخرجات قابلة للإضافة من المدير (الخمسة الأساسية تُزرع عند التهيئة)
  '''CREATE TABLE output_types(
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    data_type TEXT NOT NULL CHECK(data_type IN ('count','date','size_mb','text')),
    is_builtin INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL
  )''',
  '''CREATE TABLE task_outputs(
    id TEXT PRIMARY KEY,
    task_id TEXT NOT NULL REFERENCES field_tasks(id),
    output_type_id TEXT NOT NULL REFERENCES output_types(id),
    value_text TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )''',

  // ---------- المخزن والتجهيزات ----------
  '''CREATE TABLE inventory_items(
    id TEXT PRIMARY KEY,
    serial INTEGER UNIQUE,
    name TEXT NOT NULL UNIQUE, category TEXT,
    quantity INTEGER NOT NULL DEFAULT 0 CHECK(quantity >= 0),
    condition TEXT,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
    updated_at TEXT NOT NULL
  )''',
  // حركات: in (وارد) / issue (صرف) / return (إرجاع)
  '''CREATE TABLE inventory_moves(
    id TEXT PRIMARY KEY,
    item_id TEXT NOT NULL REFERENCES inventory_items(id),
    move_type TEXT NOT NULL CHECK(move_type IN ('in','issue','return')),
    quantity INTEGER NOT NULL CHECK(quantity > 0),
    center_id TEXT REFERENCES centers(id),
    receiver_name TEXT,
    notes TEXT,
    moved_at TEXT NOT NULL,
    created_by TEXT REFERENCES users(id),
    updated_at TEXT NOT NULL
  )''',
  '''CREATE TABLE center_equipment(
    id TEXT PRIMARY KEY,
    center_id TEXT NOT NULL REFERENCES centers(id),
    item_id TEXT NOT NULL REFERENCES inventory_items(id),
    quantity INTEGER NOT NULL DEFAULT 0 CHECK(quantity >= 0),
    received_at TEXT, notes TEXT,
    updated_at TEXT NOT NULL,
    UNIQUE(center_id, item_id)
  )''',
  // الصيانة: مصدر محدد وحالات معتمدة وبيانات دورة الإصلاح
  '''CREATE TABLE maintenance(
    id TEXT PRIMARY KEY,
    item_id TEXT NOT NULL REFERENCES inventory_items(id),
    source_type TEXT NOT NULL DEFAULT 'center' CHECK(source_type IN ('warehouse','center')),
    center_id TEXT REFERENCES centers(id),
    quantity INTEGER NOT NULL DEFAULT 1 CHECK(quantity > 0),
    fault_type TEXT, assigned_to TEXT, started_at TEXT, completed_at TEXT,
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open','inspection','repairing','completed','cancelled')),
    created_at TEXT NOT NULL, updated_at TEXT NOT NULL
  )''',

  // ---------- التقييم ----------
  // الأوزان المقترحة تُزرع بعلامة is_final=0 (غير معتمدة) ويعدلها المدير وحده
  '''CREATE TABLE evaluation_criteria(
    id TEXT PRIMARY KEY,
    axis TEXT NOT NULL,
    name TEXT NOT NULL UNIQUE,
    weight REAL NOT NULL CHECK(weight > 0 AND weight <= 100),
    is_final INTEGER NOT NULL DEFAULT 0,
    sort_order INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL
  )''',
  '''CREATE TABLE evaluations(
    id TEXT PRIMARY KEY,
    center_id TEXT NOT NULL REFERENCES centers(id),
    year INTEGER NOT NULL, month INTEGER NOT NULL CHECK(month BETWEEN 1 AND 12),
    total_score REAL,
    notes TEXT,
    locked INTEGER NOT NULL DEFAULT 0,
    created_by TEXT REFERENCES users(id),
    created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
    UNIQUE(center_id, year, month)
  )''',
  '''CREATE TABLE evaluation_scores(
    id TEXT PRIMARY KEY,
    evaluation_id TEXT NOT NULL REFERENCES evaluations(id),
    criterion_id TEXT NOT NULL REFERENCES evaluation_criteria(id),
    score REAL NOT NULL,
    updated_at TEXT NOT NULL,
    UNIQUE(evaluation_id, criterion_id)
  )''',
  // نسخ التعديلات على التقييمات المؤرشفة (المدير وحده)
  '''CREATE TABLE evaluation_revisions(
    id TEXT PRIMARY KEY,
    evaluation_id TEXT NOT NULL REFERENCES evaluations(id),
    snapshot_json TEXT NOT NULL,
    reason TEXT NOT NULL,
    changed_by TEXT NOT NULL REFERENCES users(id),
    changed_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )''',
  '''CREATE TABLE delivered_materials(
    id TEXT PRIMARY KEY,
    center_id TEXT NOT NULL REFERENCES centers(id),
    name TEXT NOT NULL, delivered_at TEXT,
    size_value REAL NOT NULL, size_unit TEXT NOT NULL CHECK(size_unit IN ('MB','GB')),
    accepted INTEGER CHECK(accepted IN (0,1)),
    rejection_reason TEXT,
    updated_at TEXT NOT NULL
  )''',

  // ---------- هوية القناة وصور النظرة العامة والمرفقات ----------
  '''CREATE TABLE settings(
    key TEXT PRIMARY KEY, value TEXT, updated_at TEXT NOT NULL
  )''',
  '''CREATE TABLE overview_images(
    id TEXT PRIMARY KEY,
    attachment_id TEXT NOT NULL REFERENCES attachments(id),
    sort_order INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL
  )''',
  '''CREATE TABLE attachments(
    id TEXT PRIMARY KEY,
    file_name TEXT NOT NULL,
    relative_path TEXT NOT NULL,
    sha256 TEXT NOT NULL UNIQUE,
    size_bytes INTEGER NOT NULL,
    updated_at TEXT NOT NULL
  )''',

  // ---------- السجلات (لا تُعدَّل ولا تُحذف من الواجهة) ----------
  '''CREATE TABLE audit_log(
    id TEXT PRIMARY KEY,
    user_id TEXT, section TEXT NOT NULL, action TEXT NOT NULL,
    details TEXT, at TEXT NOT NULL
  )''',
  '''CREATE TABLE security_log(
    id TEXT PRIMARY KEY,
    username TEXT, event TEXT NOT NULL, details TEXT, at TEXT NOT NULL
  )''',
  // قيود مرجعية إضافية لا يمكن التعبير عنها بمفتاح أجنبي بسيط.
  '''CREATE TRIGGER task_supervisor_center_insert BEFORE INSERT ON field_tasks
    WHEN NOT EXISTS (SELECT 1 FROM media_staff s WHERE s.id=NEW.supervisor_staff_id AND s.center_id=NEW.center_id)
    BEGIN SELECT RAISE(ABORT, 'مشرف المهمة يجب أن يكون تابعاً لمركز المهمة'); END''',
  '''CREATE TRIGGER task_supervisor_center_update BEFORE UPDATE OF supervisor_staff_id, center_id ON field_tasks
    WHEN NOT EXISTS (SELECT 1 FROM media_staff s WHERE s.id=NEW.supervisor_staff_id AND s.center_id=NEW.center_id)
    BEGIN SELECT RAISE(ABORT, 'مشرف المهمة يجب أن يكون تابعاً لمركز المهمة'); END''',
  '''CREATE TRIGGER staff_supervisor_center_guard BEFORE UPDATE OF center_id ON media_staff
    WHEN EXISTS (SELECT 1 FROM field_tasks t WHERE t.supervisor_staff_id=OLD.id AND t.center_id<>NEW.center_id)
    BEGIN SELECT RAISE(ABORT, 'لا يمكن نقل الإعلامي؛ فهو مشرف على مهام في مركزه الحالي'); END''',
  '''CREATE TRIGGER audit_log_no_update BEFORE UPDATE ON audit_log BEGIN SELECT RAISE(ABORT, 'audit_log is immutable'); END''',
  '''CREATE TRIGGER audit_log_no_delete BEFORE DELETE ON audit_log BEGIN SELECT RAISE(ABORT, 'audit_log is immutable'); END''',
  '''CREATE TRIGGER security_log_no_update BEFORE UPDATE ON security_log BEGIN SELECT RAISE(ABORT, 'security_log is immutable'); END''',
  '''CREATE TRIGGER security_log_no_delete BEFORE DELETE ON security_log BEGIN SELECT RAISE(ABORT, 'security_log is immutable'); END''',
  '''CREATE TRIGGER evaluation_revision_no_update BEFORE UPDATE ON evaluation_revisions BEGIN SELECT RAISE(ABORT, 'evaluation_revisions is immutable'); END''',
  '''CREATE TRIGGER evaluation_revision_no_delete BEFORE DELETE ON evaluation_revisions BEGIN SELECT RAISE(ABORT, 'evaluation_revisions is immutable'); END''',
  '''CREATE TRIGGER criteria_axis_weight_total BEFORE UPDATE OF is_final ON evaluation_criteria
    WHEN NEW.is_final = 1 AND ABS((SELECT COALESCE(SUM(weight),0) FROM evaluation_criteria WHERE axis=NEW.axis) - 100.0) > 0.01
    BEGIN SELECT RAISE(ABORT, 'مجموع أوزان معايير المحور يجب أن يساوي 100'); END''',
  '''CREATE TRIGGER evaluation_score_valid_insert BEFORE INSERT ON evaluation_scores
    WHEN NEW.score < 0 OR NEW.score > COALESCE((SELECT weight FROM evaluation_criteria WHERE id=NEW.criterion_id), -1)
      OR ABS(NEW.score*100 - ROUND(NEW.score*100)) > 0.000001
    BEGIN SELECT RAISE(ABORT, 'درجة المعيار خارج النطاق أو تتجاوز منزلتين عشريتين'); END''',
  '''CREATE TRIGGER evaluation_score_valid_update BEFORE UPDATE OF score, criterion_id ON evaluation_scores
    WHEN NEW.score < 0 OR NEW.score > COALESCE((SELECT weight FROM evaluation_criteria WHERE id=NEW.criterion_id), -1)
      OR ABS(NEW.score*100 - ROUND(NEW.score*100)) > 0.000001
    BEGIN SELECT RAISE(ABORT, 'درجة المعيار خارج النطاق أو تتجاوز منزلتين عشريتين'); END''',

];

/// الجداول التي تدخل في ملف التصدير والاستيراد (بترتيب يحترم المفاتيح الأجنبية).
/// جدولا users وsecurity_log لا يُصدَّران افتراضياً: لا نُصدّر هاشات كلمات المرور.
const List<String> kTransferTables = [
  'centers', 'media_staff', 'staff_courses', 'staff_experience',
  'field_tasks', 'task_staff', 'output_types', 'task_outputs',
  'inventory_items', 'inventory_moves', 'center_equipment', 'maintenance',
  'evaluation_criteria', 'evaluations', 'evaluation_scores', 'evaluation_revisions',
  'delivered_materials', 'settings', 'overview_images', 'attachments',
];
