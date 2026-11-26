import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/db/app_database.dart';
import '../../core/permissions.dart';
import '../../core/widgets.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, required this.app, required this.user});
  final AppDatabase app;
  final Map<String, Object?> user;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _search = TextEditingController();
  String _q = '';
  String? _status;
  late Future<List<Map<String, Object?>>> _rows;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  void _clearFilters() {
    _search.clear();
    _q = '';
    _status = null;
    _reload();
  }

  void _reload() => setState(() {
        final args = <Object?>['%$_q%'];
        var where = 't.title LIKE ?';
        if (_status != null) {
          where += ' AND t.status = ?';
          args.add(_status);
        }
        _rows = widget.app.db.rawQuery('''
          SELECT t.*, c.name AS center_name
          FROM field_tasks t
          LEFT JOIN centers c ON c.id = t.center_id
          WHERE $where
          ORDER BY t.start_date DESC
        ''', args);
      });

  Future<void> _add() async {
    final role = Role.parse(widget.user['role']);
    if (!role.canEditOperations) return;
    final centers = await widget.app.db.query('centers', where: "status = 'active'", orderBy: 'serial');
    final staff = await widget.app.db.query('media_staff', where: "status = 'active'", orderBy: 'serial');
    if (!mounted) return;
    if (centers.isEmpty) {
      toast(context, 'أضف مركزاً نشطاً أولاً.');
      return;
    }
    final values = await showRecordForm(
      context,
      title: 'مهمة ميدانية جديدة',
      fields: [
        const FieldSpec('title', 'عنوان المهمة', required: true),
        const FieldSpec('task_type', 'نوع المهمة', type: FieldType.dropdown, required: true, options: [
          ('تغطية', 'تغطية'),
          ('تصوير', 'تصوير'),
          ('توثيق', 'توثيق'),
          ('إنتاج', 'إنتاج'),
          ('أخرى', 'أخرى'),
        ]),
        FieldSpec('center_id', 'المركز المسؤول', type: FieldType.dropdown, required: true, options: [
          for (final c in centers) ('${c['id']}', '${c['name']}'),
        ]),
        FieldSpec('supervisor_staff_id', 'مشرف المهمة (من المركز المسؤول)', type: FieldType.dropdown, required: true, options: [
          for (final s in staff) ('${s['id']}', '${s['full_name']} — ${s['center_id']}'),
        ]),
        const FieldSpec('location', 'موقع التنفيذ'),
        const FieldSpec('start_date', 'تاريخ البداية', type: FieldType.date, required: true),
        const FieldSpec('end_date', 'تاريخ النهاية', type: FieldType.date),
        const FieldSpec('description', 'وصف المهمة', type: FieldType.multiline),
        const FieldSpec('notes', 'ملاحظات', type: FieldType.multiline),
      ],
    );
    if (values == null) return;
    Map<String, Object?>? supervisor;
    for (final member in staff) {
      if (member['id'] == values['supervisor_staff_id']) { supervisor = member; break; }
    }
    if (supervisor == null || supervisor['center_id'] != values['center_id']) {
      toast(context, 'يجب اختيار مشرف تابع للمركز المسؤول عن المهمة.');
      return;
    }
    final t = nowIso();
    final id = newId();
    await widget.app.db.insert('field_tasks', {
      'id': id,
      'serial': (Sqflite.firstIntValue(await widget.app.db.rawQuery('SELECT MAX(serial) FROM field_tasks')) ?? 0) + 1,
      'title': values['title'],
      'task_type': values['task_type'],
      'center_id': values['center_id'],
      'supervisor_staff_id': values['supervisor_staff_id'],
      'location': values['location'],
      'start_date': values['start_date'],
      'end_date': values['end_date'],
      'description': values['description'],
      'notes': values['notes'],
      'status': 'planned',
      'progress_percent': 0,
      'created_by': widget.user['id'],
      'created_at': t,
      'updated_at': t,
    });
    await widget.app.audit('${widget.user['id']}', 'field_tasks', 'add', '${values['title']}');
    _reload();
  }

  Future<void> _changeStatus(Map<String, Object?> task) async {
    final role = Role.parse(widget.user['role']);
    if (!role.canEditOperations) return;
    final values = await showRecordForm(
      context,
      title: 'متابعة المهمة',
      fields: const [
        FieldSpec('status', 'حالة المهمة', type: FieldType.dropdown, required: true, options: [
          ('planned', 'مخططة'),
          ('running', 'جارية'),
          ('done', 'منتهية'),
          ('cancelled', 'ملغية'),
        ]),
        FieldSpec('progress_percent', 'نسبة الإنجاز', type: FieldType.integer),
        FieldSpec('progress_notes', 'آخر المستجدات والملاحظات', type: FieldType.multiline),
        FieldSpec('actual_end', 'تاريخ الانتهاء الفعلي', type: FieldType.date),
      ],
      initial: task,
    );
    if (values == null) return;
    final progress = int.tryParse('${values['progress_percent'] ?? ''}')?.clamp(0, 100);
    await widget.app.db.update(
      'field_tasks',
      {
        'status': values['status'],
        'progress_percent': progress,
        'progress_notes': values['progress_notes'],
        'actual_end': values['actual_end'],
        'updated_at': nowIso(),
      },
      where: 'id = ?',
      whereArgs: [task['id']],
    );
    await widget.app.audit('${widget.user['id']}', 'field_tasks', 'update_progress', '${task['title']}');
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final role = Role.parse(widget.user['role']);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageIntro(title: 'إدارة المهام الميدانية',
            subtitle: 'متابعة خطط التنفيذ وحالات الإنجاز والجهة المشرفة على كل مهمة.',
            action: role.canEditOperations ? FilledButton.icon(onPressed: _add,
              icon: const Icon(Symbols.add), label: const Text('مهمة جديدة')) : null),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _search,
                  onChanged: (value) {
                    _q = value;
                    _reload();
                  },
                  decoration: InputDecoration(
                    hintText: 'بحث بعنوان المهمة',
                    prefixIcon: const Icon(Symbols.search),
                    suffixIcon: _q.isEmpty ? null : IconButton(
                      tooltip: 'مسح البحث', icon: const Icon(Symbols.close),
                      onPressed: () { _search.clear(); _q = ''; _reload(); }),
                  ),
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'الحالة'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('الكل')),
                    DropdownMenuItem(value: 'planned', child: Text('مخططة')),
                    DropdownMenuItem(value: 'running', child: Text('جارية')),
                    DropdownMenuItem(value: 'done', child: Text('منتهية')),
                    DropdownMenuItem(value: 'cancelled', child: Text('ملغية')),
                  ],
                  onChanged: (value) {
                    _status = value;
                    _reload();
                  },
                ),
              ),
              OutlinedButton.icon(onPressed: _clearFilters, icon: const Icon(Symbols.filter_alt_off), label: const Text('مسح التصفية')),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: _rows,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return LoadFailure(message: 'تعذر تحميل المهام الميدانية.', onRetry: _reload);
                final rows = snapshot.data ?? const <Map<String, Object?>>[];
                if (rows.isEmpty) return const EmptyState('لا توجد مهام ميدانية مطابقة.');
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final task = rows[index];
                    final progress = (task['progress_percent'] as int?) ?? 0;
                    return Card(
                      child: ListTile(
                        leading: Icon(Symbols.assignment, color: Theme.of(context).colorScheme.primary),
                        title: Text('${task['title']}'),
                        subtitle: Text('${task['center_name'] ?? '—'} • ${task['location'] ?? '—'} • نسبة الإنجاز: $progress%'),
                        trailing: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            StatusChip('${task['status']}'),
                            if (role.canEditOperations)
                              IconButton(
                                tooltip: 'متابعة',
                                onPressed: () => _changeStatus(task),
                                icon: const Icon(Symbols.edit_note),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
