import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/db/app_database.dart';
import '../../core/permissions.dart';
import '../../core/widgets.dart';
import '../centers/centers_repository.dart';
import 'staff_repository.dart';

/// ملف الإعلامي: أربعة أقسام (شخصية، وظيفية، مهام، دورات وخبرات) حسب الوثيقة 6.1.
class StaffProfileScreen extends StatefulWidget {
  const StaffProfileScreen({super.key, required this.app, required this.user, required this.staffId});
  final AppDatabase app;
  final DbRow user;
  final String staffId;
  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  late final repo = StaffRepository(widget.app, widget.user['id'] as String);
  late final role = Role.parse(widget.user['role']);
  Future<Map<String, Object?>>? _data;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _data = (() async => <String, Object?>{
          'p': await repo.byId(widget.staffId),
          'tasks': await repo.tasksOf(widget.staffId),
          'courses': await repo.courses(widget.staffId),
          'exp': await repo.experiences(widget.staffId),
        })();
    setState(() {});
  }

  Future<void> _edit(DbRow p) async {
    final centers = await CentersRepository(widget.app, '').all();
    if (!mounted) return;
    final v = await showRecordForm(context,
        title: 'تعديل بيانات الإعلامي', fields: StaffRepository.formFields(centers), initial: p);
    if (v == null) return;
    await repo.save(v, id: widget.staffId);
    _reload();
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'سيتم حذف ملف الإعلامي نهائياً. هل أنت متأكد؟')) return;
    final err = await repo.delete(widget.staffId);
    if (!mounted) return;
    if (err != null) { toast(context, err); return; }
    Navigator.pop(context);
  }


  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, Object?>>(
      future: _data,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (snap.hasError) return Scaffold(body: LoadFailure(message: 'تعذر تحميل ملف الإعلامي.', onRetry: _reload));
        final p = snap.data!['p'] as DbRow?;
        if (p == null) return const Scaffold(body: EmptyState('الملف غير موجود'));
        final tasks = snap.data!['tasks'] as List<DbRow>;
        final courses = snap.data!['courses'] as List<DbRow>;
        final exp = snap.data!['exp'] as List<DbRow>;
        final cs = Theme.of(context).colorScheme;
        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: Text('${p['full_name']}'),
              actions: [
                if (role.canEditOperations) ...[
                  IconButton(tooltip: 'تعديل', icon: const Icon(Symbols.edit), onPressed: () => _edit(p)),
                  IconButton(tooltip: 'حذف', icon: const Icon(Symbols.delete), onPressed: _delete),
                ],
              ],
              bottom: const TabBar(isScrollable: true, tabs: [
                Tab(text: 'البيانات الشخصية'), Tab(text: 'البيانات الوظيفية'),
                Tab(text: 'المهام الميدانية'), Tab(text: 'الدورات والخبرات'),
              ]),
            ),
            body: Column(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  CircleAvatar(radius: 34, backgroundColor: cs.primary.withValues(alpha: 0.12),
                      child: Icon(Symbols.person, size: 36, color: cs.primary)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${p['full_name']}', style: Theme.of(context).textTheme.titleLarge),
                    Text('رقم تسلسلي: ${p['serial']}  •  ${p['center_name'] ?? '—'}  •  ${p['specialty'] ?? '—'}'),
                  ])),
                  StatusChip('${p['status']}'),
                ]),
              ),
              Expanded(
                child: TabBarView(children: [
                  SingleChildScrollView(child: DetailGrid(items: [
                    ('الاسم الكامل', p['full_name']), ('تاريخ الميلاد', p['birth_date']),
                    ('رقم الجوال', p['phone']), ('المحافظة', p['governorate']),
                    ('المديرية', p['district']), ('المنطقة', p['area']),
                  ])),
                  SingleChildScrollView(child: DetailGrid(items: [
                    ('المركز التابع له', p['center_name']), ('التخصص الإعلامي', p['specialty']),
                    ('تاريخ الانضمام', p['joined_at']), ('الحالة', statusLabels[p['status']]),
                    ('المؤهل العلمي', p['qualification']),
                  ])),
                  tasks.isEmpty
                      ? const EmptyState('لا توجد مهام مرتبطة بهذا الإعلامي بعد.\nتظهر هنا تلقائياً من قسم المهام الميدانية.')
                      : ListView(children: [
                          for (final t in tasks)
                            ListTile(
                              title: Text('${t['title']}'),
                              subtitle: Text('${t['center_name'] ?? '—'}  •  ${t['start_date'] ?? '—'}'),
                              trailing: StatusChip('${t['status']}'),
                            ),
                        ]),
                  ListView(children: [
                    _SectionBar('الدورات التدريبية', role.canEditOperations ? () async {
                      final v = await showRecordForm(context, title: 'إضافة دورة', fields: const [
                        FieldSpec('course_name', 'اسم الدورة', required: true),
                        FieldSpec('issuer', 'الجهة المنظمة أو المانحة'),
                        FieldSpec('obtained_at', 'تاريخ الحصول عليها', type: FieldType.date),
                      ]);
                      if (v != null) { await repo.addCourse(widget.staffId, v); _reload(); }
                    } : null),
                    if (courses.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('لا توجد دورات مسجلة.')),
                    for (final c in courses)
                      ListTile(
                        title: Text('${c['course_name']}'),
                        subtitle: Text('${c['issuer'] ?? '—'}  •  ${c['obtained_at'] ?? '—'}'),
                        trailing: role.canEditOperations
                            ? IconButton(icon: const Icon(Symbols.delete), onPressed: () async {
                                if (await confirm(context, 'حذف هذه الدورة؟')) { await repo.deleteCourse('${c['id']}'); _reload(); }
                              })
                            : null,
                      ),
                    _SectionBar('الخبرات الإعلامية السابقة', role.canEditOperations ? () async {
                      final v = await showRecordForm(context, title: 'إضافة خبرة', fields: const [
                        FieldSpec('description', 'الخبرة', type: FieldType.multiline, required: true),
                        FieldSpec('duration', 'مدة الخبرة'),
                      ]);
                      if (v != null) { await repo.addExperience(widget.staffId, v); _reload(); }
                    } : null),
                    if (exp.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('لا توجد خبرات مسجلة.')),
                    for (final e in exp)
                      ListTile(
                        title: Text('${e['description']}'),
                        subtitle: Text('المدة: ${e['duration'] ?? '—'}'),
                        trailing: role.canEditOperations
                            ? IconButton(icon: const Icon(Symbols.delete), onPressed: () async {
                                if (await confirm(context, 'حذف هذه الخبرة؟')) { await repo.deleteExperience('${e['id']}'); _reload(); }
                              })
                            : null,
                      ),
                  ]),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _SectionBar extends StatelessWidget {
  const _SectionBar(this.title, this.onAdd);
  final String title;
  final VoidCallback? onAdd;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
        child: Row(children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          if (onAdd != null) TextButton.icon(onPressed: onAdd, icon: const Icon(Symbols.add), label: const Text('إضافة')),
        ]),
      );
}
