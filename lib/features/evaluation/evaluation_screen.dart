import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/db/app_database.dart';
import '../../core/permissions.dart';
import '../../core/widgets.dart';

class EvaluationScreen extends StatefulWidget {
  const EvaluationScreen({super.key, required this.app, required this.user});
  final AppDatabase app;
  final Map<String, Object?> user;

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  late Future<List<Map<String, Object?>>> _rows;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() {
        _rows = widget.app.db.rawQuery('''
          SELECT c.*, e.id AS evaluation_id, e.year, e.month, e.total_score, e.locked
          FROM centers c
          LEFT JOIN evaluations e ON e.id = (
            SELECT e2.id FROM evaluations e2
            WHERE e2.center_id = c.id
            ORDER BY e2.year DESC, e2.month DESC
            LIMIT 1
          )
          ORDER BY c.serial
        ''');
      });

  Future<void> _evaluate(Map<String, Object?> center) async {
    final role = Role.parse(widget.user['role']);
    if (!role.canEditOperations) return;
    final now = DateTime.now();
    final values = await showRecordForm(
      context,
      title: 'تقييم ${center['name']}',
      fields: [
        FieldSpec('year', 'السنة', type: FieldType.integer, required: true),
        FieldSpec('month', 'الشهر (1-12)', type: FieldType.integer, required: true),
        const FieldSpec('total_score', 'النتيجة النهائية %', type: FieldType.decimal, required: true),
        const FieldSpec('notes', 'الملاحظات والنتائج', type: FieldType.multiline),
      ],
      initial: {
        'year': '${now.year}',
        'month': '${now.month}',
      },
    );
    if (values == null) return;
    final year = int.tryParse('${values['year']}');
    final month = int.tryParse('${values['month']}');
    final score = double.tryParse('${values['total_score']}');
    if (year == null || month == null || month < 1 || month > 12 || score == null) {
      toast(context, 'تحقق من السنة والشهر والنتيجة النهائية.');
      return;
    }
    if (score < 0 || score > 100) {
      toast(context, 'النتيجة يجب أن تكون بين 0 و100.');
      return;
    }
    final t = nowIso();
    final data = {
        'id': newId(),
        'center_id': center['id'],
        'year': year,
        'month': month,
        'total_score': score,
        'notes': values['notes'],
        'locked': 1,
        'created_by': widget.user['id'],
        'created_at': t,
        'updated_at': t,
      };
    final existing = await widget.app.db.query(
      'evaluations',
      where: 'center_id = ? AND year = ? AND month = ?',
      whereArgs: [center['id'], year, month],
      limit: 1,
    );
    if (existing.isEmpty) {
      await widget.app.db.insert('evaluations', data);
    } else {
      if ((existing.first['locked'] as int?) == 1 &&
          role != Role.manager) {
        toast(context, 'التقييم المؤرشف لا يعدله إلا المدير.');
        return;
      }
      await widget.app.db.update(
        'evaluations',
        {
          'total_score': score,
          'notes': values['notes'],
          'locked': 1,
          'updated_at': t,
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
      await widget.app.audit(
        '${widget.user['id']}',
        'evaluations',
        'revision',
        '${center['name']} $year/$month',
      );
    }
    await widget.app.audit('${widget.user['id']}', 'evaluations', 'evaluate', '${center['name']} $year/$month');
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final role = Role.parse(widget.user['role']);
    return FutureBuilder<List<Map<String, Object?>>>(
      future: _rows,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return LoadFailure(message: 'تعذر تحميل بيانات التقييم.', onRetry: _reload);
        final rows = snapshot.data ?? const <Map<String, Object?>>[];
        if (rows.isEmpty) return const EmptyState('لا توجد مراكز متاحة للتقييم.');
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageIntro(title: 'التقييم الدوري للمراكز',
              subtitle: 'استعراض آخر نتيجة مسجلة لكل مركز وإدخال نتيجة التقييم.',
              action: null),
            for (final center in rows)
              Card(
                child: ListTile(
                  leading: const Icon(Symbols.analytics),
                  title: Text('${center['name']}'),
                  subtitle: Text(
                    center['total_score'] == null
                        ? 'لم يتم التقييم بعد'
                        : 'آخر تقييم: ${center['year']}/${center['month']} • النتيجة ${center['total_score']}%',
                  ),
                  trailing: role.canEditOperations
                      ? FilledButton.tonalIcon(
                          onPressed: () => _evaluate(center),
                          icon: const Icon(Symbols.edit),
                          label: const Text('إدخال تقييم'),
                        )
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}
