import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/db/app_database.dart';
import '../../core/permissions.dart';
import '../../core/widgets.dart';
import '../staff/staff_profile_screen.dart';
import '../staff/staff_repository.dart';
import 'centers_repository.dart';
import 'centers_screen.dart' show centerFields;

/// ملف المركز: الإعلاميون، التجهيزات، المهام (الوثيقة 5.3).
class CenterDetailScreen extends StatefulWidget {
  const CenterDetailScreen({super.key, required this.app, required this.user, required this.centerId});
  final AppDatabase app;
  final Row user;
  final String centerId;
  @override
  State<CenterDetailScreen> createState() => _CenterDetailScreenState();
}

class _CenterDetailScreenState extends State<CenterDetailScreen> {
  late final repo = CentersRepository(widget.app, widget.user['id'] as String);
  late final staffRepo = StaffRepository(widget.app, widget.user['id'] as String);
  late final role = Role.parse(widget.user['role']);
  Future<Map<String, Object?>>? _data;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _data = () async => {
          'c': await repo.byId(widget.centerId),
          'staff': await repo.staffOf(widget.centerId),
          'equip': await repo.equipmentOf(widget.centerId),
          'tasks': await repo.tasksOf(widget.centerId),
        }();
    setState(() {});
  }

  Future<void> _edit(Row c) async {
    final v = await showRecordForm(context, title: 'تعديل المركز', fields: centerFields, initial: c);
    if (v == null) return;
    await repo.save(v, id: widget.centerId);
    _reload();
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'سيتم حذف المركز نهائياً. هل أنت متأكد؟')) return;
    final err = await repo.delete(widget.centerId);
    if (!mounted) return;
    if (err != null) { toast(context, err); return; }
    Navigator.pop(context);
  }

  Future<void> _addStaff(Row c) async {
    final centers = await repo.all();
    if (!mounted) return;
    // المركز محدد مسبقاً؛ الإعلامي المضاف يظهر تلقائياً في قسم الكادر العام (نفس الجدول)
    final v = await showRecordForm(context,
        title: 'إضافة إعلامي إلى ${c['name']}',
        fields: StaffRepository.formFields(centers),
        initial: {'center_id': widget.centerId, 'status': 'active'});
    if (v == null) return;
    await staffRepo.save(v);
    _reload();
  }


  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, Object?>>(
      future: _data,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (snap.hasError) return Scaffold(body: LoadFailure(message: 'تعذر تحميل بيانات المركز.', onRetry: _reload));
        final c = snap.data!['c'] as Row?;
        if (c == null) return const Scaffold(body: EmptyState('المركز غير موجود'));
        final staff = snap.data!['staff'] as List<Row>;
        final equip = snap.data!['equip'] as List<Row>;
        final tasks = snap.data!['tasks'] as List<Row>;
        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: Text('${c['name']}'),
              actions: [
                if (role.canEditOperations) ...[
                  IconButton(tooltip: 'تعديل', icon: const Icon(Symbols.edit), onPressed: () => _edit(c)),
                  IconButton(tooltip: 'حذف', icon: const Icon(Symbols.delete), onPressed: _delete),
                ],
              ],
              bottom: const TabBar(isScrollable: true, tabs: [
                Tab(text: 'بيانات المركز'), Tab(text: 'الإعلاميون'), Tab(text: 'التجهيزات'), Tab(text: 'المهام'),
              ]),
            ),
            body: TabBarView(children: [
              SingleChildScrollView(child: DetailGrid(items: [
                ('الرقم التسلسلي', c['serial']), ('المحافظة', c['governorate']),
                ('المديرية', c['district']), ('المنطقة', c['area']),
                ('العنوان التفصيلي', c['address']), ('الهاتف الرسمي', c['phone']),
                ('اسم المسؤول', c['manager_name']), ('رقم جوال المسؤول', c['manager_phone']),
                ('تاريخ التأسيس', c['founded_at']), ('الحالة', statusLabels[c['status']]),
                ('ملاحظات', c['notes']),
              ])),
              Column(children: [
                if (role.canEditOperations)
                  Align(alignment: AlignmentDirectional.centerStart, child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton.icon(onPressed: () => _addStaff(c),
                        icon: const Icon(Symbols.person_add), label: const Text('إضافة إعلامي')),
                  )),
                Expanded(child: staff.isEmpty
                    ? const EmptyState('لا يوجد إعلاميون في هذا المركز.')
                    : ListView(children: [
                        for (final s in staff)
                          ListTile(
                            leading: CircleAvatar(child: Text('${s['serial']}')),
                            title: Text('${s['full_name']}'),
                            subtitle: Text('${s['specialty'] ?? '—'}'),
                            trailing: StatusChip('${s['status']}'),
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => StaffProfileScreen(app: widget.app, user: widget.user, staffId: '${s['id']}')));
                              _reload();
                            },
                          ),
                      ])),
              ]),
              equip.isEmpty
                  ? const EmptyState('لا توجد تجهيزات مستلمة من المخزن.\nتظهر هنا تلقائياً عند اعتماد عمليات الصرف.')
                  : ListView(children: [
                      for (final e in equip)
                        ListTile(title: Text('${e['name']}'), subtitle: Text('الحالة: ${e['condition'] ?? '—'}'),
                            trailing: Text('الكمية: ${e['quantity']}')),
                    ]),
              tasks.isEmpty
                  ? const EmptyState('لا توجد مهام مسندة لهذا المركز.\nتظهر هنا تلقائياً من قسم المهام الميدانية.')
                  : ListView(children: [
                      for (final t in tasks)
                        ListTile(
                          title: Text('${t['title']}'),
                          subtitle: Text('${t['location'] ?? '—'}  •  ${t['start_date'] ?? '—'} إلى ${t['end_date'] ?? '—'}'),
                          trailing: StatusChip('${t['status']}'),
                        ),
                    ]),
            ]),
          ),
        );
      },
    );
  }
}
