import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/db/app_database.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.app, required this.user});
  final AppDatabase app;
  final Map<String, Object?> user;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<Map<String, int>>? _counts;

  static const _cards = [
    (Symbols.admin_panel_settings, 'الإدارة', 'حسابات النظام'),
    (Symbols.apartment, 'المراكز', 'المراكز الإعلامية'),
    (Symbols.groups, 'الكادر الإعلامي', 'ملفات الإعلاميين'),
    (Symbols.assignment, 'المهام الميدانية', 'المهام المسجلة'),
    (Symbols.inventory_2, 'التجهيزات', 'أصناف المخزون'),
    (Symbols.analytics, 'التقييمات', 'سجلات التقييم'),
  ];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _counts = _loadCounts();

  Future<Map<String, int>> _loadCounts() async {
    Future<int> count(String table) async =>
        Sqflite.firstIntValue(await widget.app.db.rawQuery('SELECT COUNT(*) FROM $table')) ?? 0;
    return {
      'الإدارة': await count('admin_profiles'),
      'المراكز': await count('centers'),
      'الكادر الإعلامي': await count('media_staff'),
      'المهام الميدانية': await count('field_tasks'),
      'التجهيزات': await count('inventory_items'),
      'التقييمات': await count('evaluations'),
    };
  }

  Future<void> _refresh() async {
    setState(_reload);
    try { await _counts; } catch (_) { /* يعرض FutureBuilder حالة الخطأ */ }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1250 ? 3 : (constraints.maxWidth >= 720 ? 2 : 1);
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: constraints.maxWidth >= 900 ? 28 : 16, vertical: 24),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('مرحباً بك في النظام', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 5),
                Text('إليك ملخصاً سريعاً عن بيانات النظام المسجلة حالياً.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: .65))),
                const SizedBox(height: 24),
                Row(children: [
                  Container(width: 4, height: 23, decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(width: 9),
                  Text('مؤشرات النظام', style: Theme.of(context).textTheme.titleLarge),
                ]),
                const SizedBox(height: 14),
                FutureBuilder<Map<String, int>>(
                  future: _counts,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(padding: EdgeInsets.symmetric(vertical: 70), child: Center(child: CircularProgressIndicator()));
                    }
                    if (snapshot.hasError) {
                      return _DashboardMessage(
                        icon: Symbols.cloud_off,
                        title: 'تعذّر تحميل المؤشرات',
                        message: 'تحقق من قاعدة البيانات ثم حاول تحديث الصفحة.',
                        action: 'إعادة المحاولة',
                        onPressed: _refresh,
                      );
                    }
                    final counts = snapshot.data ?? const <String, int>{};
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _cards.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        mainAxisExtent: 112,
                      ),
                      itemBuilder: (context, index) {
                        final item = _cards[index];
                        return _MetricCard(icon: item.$1, title: item.$2, caption: item.$3,
                          value: counts[item.$2] ?? 0);
                      },
                    );
                  },
                ),
                const SizedBox(height: 22),
                Card(child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 40, height: 40,
                      decoration: BoxDecoration(color: cs.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Symbols.info, color: cs.primary)),
                    const SizedBox(width: 13),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('حفظ البيانات', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('تُحفظ بيانات النظام محلياً على هذا الجهاز، ولا تتم مزامنتها تلقائياً مع خادم خارجي.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: .72))),
                    ])),
                  ]),
                )),
              ]),
            ),
          ],
        );
      }),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.icon, required this.title, required this.caption, required this.value});
  final IconData icon;
  final String title, caption;
  final int value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
      child: Row(children: [
        Container(width: 48, height: 48,
          decoration: BoxDecoration(color: cs.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: cs.primary, size: 25)),
        const SizedBox(width: 14),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: .58))),
        ])),
        const SizedBox(width: 8),
        Text('$value', style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: cs.primary, fontWeight: FontWeight.w800)),
      ]),
    ));
  }
}

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage({required this.icon, required this.title, required this.message, required this.action, required this.onPressed});
  final IconData icon;
  final String title, message, action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      Icon(icon, size: 36, color: Theme.of(context).colorScheme.error),
      const SizedBox(height: 10),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 14),
      OutlinedButton(onPressed: onPressed, child: Text(action)),
    ]),
  ));
}
