import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/db/app_database.dart';
import '../../core/permissions.dart';
import '../../core/widgets.dart';
import '../centers/centers_repository.dart';
import 'staff_profile_screen.dart';
import 'staff_repository.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key, required this.app, required this.user});
  final AppDatabase app;
  final Map<String, Object?> user;
  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  late final repo = StaffRepository(widget.app, widget.user['id'] as String);
  late final role = Role.parse(widget.user['role']);
  final _search = TextEditingController();
  String _q = '';
  String? _center, _status;
  Future<List<Map<String, Object?>>>? _rows;
  List<Map<String, Object?>> _centers = [];

  @override
  void initState() {
    super.initState();
    CentersRepository(widget.app, '').all().then((c) { if (mounted) setState(() => _centers = c); });
    _reload();
  }

  void _reload() => setState(() => _rows = repo.list(q: _q, centerId: _center, status: _status));

  Future<void> _add() async {
    if (_centers.isEmpty) {
      toast(context, 'أضف مركزاً أولاً من قسم المراكز ثم أضف الإعلاميين.');
      return;
    }
    final v = await showRecordForm(context,
      title: 'إضافة إعلامي', fields: StaffRepository.formFields(_centers), initial: {'status': 'active'});
    if (v == null || !mounted) return;
    await repo.save(v);
    _reload();
  }

  void _clearFilters() {
    _search.clear(); _q = ''; _center = null; _status = null; _reload();
  }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageIntro(title: 'إدارة الكادر الإعلامي',
          subtitle: 'متابعة ملفات الإعلاميين ومراكزهم وتخصصاتهم وحالاتهم الوظيفية.',
          action: role.canEditOperations ? FilledButton.icon(onPressed: _add,
            icon: const Icon(Symbols.person_add), label: const Text('إضافة إعلامي')) : null),
        Expanded(child: FutureBuilder<List<Map<String, Object?>>>(
          future: _rows,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return LoadFailure(message: 'تعذر تحميل بيانات الكادر الإعلامي.', onRetry: _reload);
            final rows = snap.data ?? const <Map<String, Object?>>[];
            final active = rows.where((r) => r['status'] == 'active').length;
            final stopped = rows.where((r) => r['status'] == 'stopped').length;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 10, runSpacing: 10, children: [
                SummaryMetric(label: 'إجمالي النتائج', value: '${rows.length}', icon: Symbols.groups),
                SummaryMetric(label: 'إعلاميون نشطون', value: '$active', icon: Symbols.person, color: cs.primary),
                SummaryMetric(label: 'إعلاميون متوقفون', value: '$stopped', icon: Symbols.person_off, color: cs.error),
              ]),
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                SizedBox(width: 300, child: TextField(controller: _search,
                  decoration: const InputDecoration(hintText: 'بحث بالاسم أو التخصص أو الجوال', prefixIcon: Icon(Symbols.search)),
                  onChanged: (v) { _q = v; _reload(); })),
                SizedBox(width: 230, child: DropdownButtonFormField<String?>(
                  value: _center, isExpanded: true, decoration: const InputDecoration(labelText: 'المركز'),
                  items: [const DropdownMenuItem(value: null, child: Text('كل المراكز')),
                    for (final c in _centers) DropdownMenuItem(value: c['id'] as String, child: Text('${c['name']}', overflow: TextOverflow.ellipsis))],
                  onChanged: (v) { _center = v; _reload(); })),
                SizedBox(width: 160, child: DropdownButtonFormField<String?>(
                  value: _status, decoration: const InputDecoration(labelText: 'الحالة'),
                  items: const [DropdownMenuItem(value: null, child: Text('الكل')),
                    DropdownMenuItem(value: 'active', child: Text('نشط')),
                    DropdownMenuItem(value: 'stopped', child: Text('متوقف'))],
                  onChanged: (v) { _status = v; _reload(); })),
                OutlinedButton.icon(onPressed: _clearFilters,
                  icon: const Icon(Symbols.filter_alt_off), label: const Text('مسح التصفية')),
              ]),
              const SizedBox(height: 14),
              Expanded(child: rows.isEmpty
                ? const EmptyState('لا يوجد إعلاميون مطابقون لمعايير البحث والتصفية.')
                : Card(child: Column(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      decoration: BoxDecoration(color: cs.surfaceContainerHighest,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
                      child: Row(children: [
                        Expanded(child: Text('الاسم والرقم التسلسلي', style: Theme.of(context).textTheme.labelLarge)),
                        if (MediaQuery.sizeOf(context).width > 700)
                          Text('المركز • التخصص • التواصل', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(width: 8), const Text('الحالة'),
                      ])),
                    Expanded(child: ListView.separated(
                      itemCount: rows.length, separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final r = rows[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: CircleAvatar(backgroundColor: cs.primary.withValues(alpha: .11),
                            foregroundColor: cs.primary, child: Text('${r['serial']}')),
                          title: Text('${r['full_name']}', style: Theme.of(context).textTheme.titleSmall),
                          subtitle: Text('${r['center_name'] ?? '—'}  •  ${r['specialty'] ?? '—'}  •  ${r['phone'] ?? '—'}',
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            StatusChip('${r['status']}'), const SizedBox(width: 4), const Icon(Symbols.chevron_left),
                          ]),
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(
                              builder: (_) => StaffProfileScreen(app: widget.app, user: widget.user, staffId: '${r['id']}')));
                            if (mounted) _reload();
                          },
                        );
                      },
                    )),
                  ])),
            ]);
          },
        )),
      ]),
    );
  }
}
