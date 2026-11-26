import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/db/app_database.dart';
import '../../core/permissions.dart';
import '../../core/widgets.dart';
import 'center_detail_screen.dart';
import 'centers_repository.dart';

const centerFields = [
  FieldSpec('name', 'اسم المركز', required: true),
  FieldSpec('governorate', 'المحافظة'),
  FieldSpec('district', 'المديرية'),
  FieldSpec('area', 'المنطقة'),
  FieldSpec('address', 'العنوان التفصيلي'),
  FieldSpec('phone', 'الهاتف الرسمي', type: FieldType.phone),
  FieldSpec('manager_name', 'اسم المسؤول'),
  FieldSpec('manager_phone', 'رقم جوال المسؤول', type: FieldType.phone),
  FieldSpec('founded_at', 'تاريخ التأسيس', type: FieldType.date),
  FieldSpec('status', 'الحالة', type: FieldType.dropdown, required: true,
      options: [('active', 'نشط'), ('stopped', 'متوقف')]),
  FieldSpec('notes', 'ملاحظات', type: FieldType.multiline),
];

class CentersScreen extends StatefulWidget {
  const CentersScreen({super.key, required this.app, required this.user});
  final AppDatabase app;
  final Map<String, Object?> user;
  @override
  State<CentersScreen> createState() => _CentersScreenState();
}

class _CentersScreenState extends State<CentersScreen> {
  late final repo = CentersRepository(widget.app, widget.user['id'] as String);
  late final role = Role.parse(widget.user['role']);
  final _search = TextEditingController();
  String _q = '';
  late Future<List<Map<String, Object?>>> _rows = repo.list();

  void _reload() => setState(() => _rows = repo.list(q: _q));

  Future<void> _add() async {
    final v = await showRecordForm(context,
        title: 'إضافة مركز', fields: centerFields, initial: {'status': 'active'});
    if (v == null || !mounted) return;
    await repo.save(v);
    _reload();
  }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageIntro(title: 'إدارة المراكز',
          subtitle: 'عرض المراكز وبياناتها ومتابعة الكادر والتجهيزات والمهام المرتبطة بها.',
          action: role.canEditOperations ? FilledButton.icon(onPressed: _add,
            icon: const Icon(Symbols.add_business), label: const Text('إضافة مركز')) : null),
        Expanded(child: FutureBuilder<List<Map<String, Object?>>>(
          future: _rows,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) return LoadFailure(message: 'تعذر تحميل قائمة المراكز.', onRetry: _reload);
            final rows = snap.data ?? const <Map<String, Object?>>[];
            final active = rows.where((r) => r['status'] == 'active').length;
            final stopped = rows.where((r) => r['status'] == 'stopped').length;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 10, runSpacing: 10, children: [
                SummaryMetric(label: 'إجمالي النتائج', value: '${rows.length}', icon: Symbols.apartment),
                SummaryMetric(label: 'مراكز نشطة', value: '$active', icon: Symbols.check_circle, color: cs.primary),
                SummaryMetric(label: 'مراكز متوقفة', value: '$stopped', icon: Symbols.pause_circle, color: cs.error),
              ]),
              const SizedBox(height: 14),
              TextField(controller: _search,
                decoration: InputDecoration(hintText: 'ابحث باسم المركز أو المحافظة أو المديرية',
                  prefixIcon: const Icon(Symbols.search),
                  suffixIcon: _q.isEmpty ? null : IconButton(icon: const Icon(Symbols.close),
                    tooltip: 'مسح البحث', onPressed: () { _search.clear(); _q = ''; _reload(); })),
                onChanged: (v) { _q = v; _reload(); }),
              const SizedBox(height: 14),
              Expanded(child: rows.isEmpty
                ? EmptyState(_q.isEmpty ? 'لا توجد مراكز مسجلة بعد. استخدم «إضافة مركز» للبدء.' : 'لا توجد نتائج تطابق عبارة البحث.')
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 390, mainAxisExtent: 174, crossAxisSpacing: 12, mainAxisSpacing: 12),
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final r = rows[i];
                      final score = (r['last_score'] as num?)?.toDouble();
                      final location = [r['governorate'], r['district'], r['area']]
                        .where((e) => e != null && '$e'.trim().isNotEmpty).join(' • ');
                      return Card(child: InkWell(
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(
                            builder: (_) => CenterDetailScreen(app: widget.app, user: widget.user, centerId: '${r['id']}')));
                          if (mounted) _reload();
                        },
                        child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Container(width: 38, height: 38,
                                decoration: BoxDecoration(color: cs.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(11)),
                                child: Icon(Symbols.apartment, color: cs.primary)),
                              const SizedBox(width: 10),
                              Expanded(child: Text('${r['name']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium)),
                            ]),
                            const SizedBox(height: 9),
                            Text(location.isEmpty ? 'الموقع غير محدد' : location, maxLines: 1,
                              overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                            const Spacer(),
                            Wrap(spacing: 7, runSpacing: 4, children: [
                              StatusChip('${r['status']}'),
                              Chip(avatar: const Icon(Symbols.groups, size: 16),
                                label: Text('${r['staff_count']} إعلامي'), visualDensity: VisualDensity.compact),
                            ]),
                          ])),
                          const SizedBox(width: 12), _ScoreRing(score),
                        ])),
                      ));
                    },
                  )),
            ]);
          },
        )),
      ]),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing(this.score);
  final double? score;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(width: 62, height: 62, child: Stack(alignment: Alignment.center, children: [
      SizedBox.expand(child: CircularProgressIndicator(value: score == null ? 0 : (score! / 100).clamp(0, 1),
        strokeWidth: 5, backgroundColor: cs.outline.withValues(alpha: .35), color: cs.primary)),
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(score == null ? '—' : '${score!.round()}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        const Text('التقييم', style: TextStyle(fontSize: 9)),
      ]),
    ]));
  }
}
