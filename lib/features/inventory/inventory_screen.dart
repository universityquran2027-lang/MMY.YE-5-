import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/db/app_database.dart';
import '../../core/permissions.dart';
import '../../core/widgets.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, required this.app, required this.user});
  final AppDatabase app;
  final Map<String, Object?> user;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _search = TextEditingController();
  String _q = '';
  late Future<List<Map<String, Object?>>> _items;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  void _reload() => setState(() {
        _items = widget.app.db.query(
          'inventory_items',
          where: _q.isEmpty ? null : 'name LIKE ?',
          whereArgs: _q.isEmpty ? null : ['%$_q%'],
          orderBy: 'serial',
        );
      });

  Future<void> _addItem() async {
    final role = Role.parse(widget.user['role']);
    if (!role.canEditOperations) return;
    final values = await showRecordForm(
      context,
      title: 'إضافة تجهيز',
      fields: const [
        FieldSpec('name', 'اسم التجهيز', required: true),
        FieldSpec('category', 'النوع'),
        FieldSpec('quantity', 'الكمية', type: FieldType.integer, required: true),
        FieldSpec('condition', 'الحالة'),
      ],
    );
    if (values == null) return;
    final quantity = int.tryParse('${values['quantity']}');
    if (quantity == null || quantity < 0) {
      toast(context, 'الكمية يجب أن تكون رقماً صحيحاً لا يقل عن صفر.');
      return;
    }
    final serial = (Sqflite.firstIntValue(await widget.app.db.rawQuery('SELECT MAX(serial) FROM inventory_items')) ?? 0) + 1;
    await widget.app.db.insert('inventory_items', {
      'id': newId(),
      'serial': serial,
      'name': values['name'],
      'category': values['category'],
      'quantity': quantity,
      'condition': values['condition'],
      'updated_at': nowIso(),
    });
    await widget.app.audit('${widget.user['id']}', 'inventory', 'add_item', '${values['name']}');
    _reload();
  }

  Future<void> _move(Map<String, Object?> item, String moveType) async {
    final role = Role.parse(widget.user['role']);
    if (!role.canEditOperations) return;
    final centers = await widget.app.db.query('centers', where: "status = 'active'", orderBy: 'serial');
    final fields = <FieldSpec>[
      const FieldSpec('quantity', 'الكمية', type: FieldType.integer, required: true),
      if (moveType != 'in')
        FieldSpec('center_id', 'المركز', type: FieldType.dropdown, required: true, options: [
          for (final c in centers) ('${c['id']}', '${c['name']}'),
        ]),
      if (moveType != 'in') const FieldSpec('receiver_name', 'اسم المستلم'),
      const FieldSpec('notes', 'ملاحظات الحركة', type: FieldType.multiline),
    ];
    final values = await showRecordForm(
      context,
      title: moveType == 'issue'
          ? 'صرف تجهيز'
          : (moveType == 'return' ? 'إرجاع تجهيز' : 'إضافة وارد'),
      fields: fields,
    );
    if (values == null) return;
    final quantity = int.tryParse('${values['quantity']}');
    if (quantity == null || quantity <= 0) {
      toast(context, 'الكمية يجب أن تكون رقماً أكبر من صفر.');
      return;
    }
    var committed = false;
    try {
      await widget.app.db.transaction((txn) async {
      final current = (await txn.query('inventory_items', where: 'id = ?', whereArgs: [item['id']], limit: 1)).first;
      var stock = (current['quantity'] as int?) ?? 0;
      if (moveType == 'issue') {
        if (quantity > stock) throw Exception('الكمية المطلوبة أكبر من الرصيد المتاح.');
        stock -= quantity;
      } else {
        stock += quantity;
      }
      await txn.update('inventory_items', {'quantity': stock, 'updated_at': nowIso()},
          where: 'id = ?', whereArgs: [item['id']]);
      if (moveType == 'issue' || moveType == 'return') {
        final centerId = values['center_id'] as String?;
        if (centerId != null) {
          final existing = await txn.query('center_equipment',
              where: 'center_id = ? AND item_id = ?', whereArgs: [centerId, item['id']], limit: 1);
          var centerQuantity = existing.isEmpty ? 0 : ((existing.first['quantity'] as int?) ?? 0);
          centerQuantity = moveType == 'issue' ? centerQuantity + quantity : centerQuantity - quantity;
          if (centerQuantity < 0) throw Exception('الكمية المرجعة أكبر من الموجود لدى المركز.');
          if (existing.isEmpty) {
            await txn.insert('center_equipment', {
              'id': newId(),
              'center_id': centerId,
              'item_id': item['id'],
              'quantity': centerQuantity,
              'received_at': nowIso(),
              'updated_at': nowIso(),
            });
          } else {
            await txn.update('center_equipment', {'quantity': centerQuantity, 'updated_at': nowIso()},
                where: 'id = ?', whereArgs: [existing.first['id']]);
          }
        }
      }
      await txn.insert('inventory_moves', {
        'id': newId(),
        'item_id': item['id'],
        'move_type': moveType,
        'quantity': quantity,
        'center_id': values['center_id'],
        'receiver_name': values['receiver_name'],
        'notes': values['notes'],
        'moved_at': nowIso(),
        'created_by': widget.user['id'],
        'updated_at': nowIso(),
      });
      });
      committed = true;
    } catch (error) {
      if (mounted) toast(context, '$error', kind: ToastKind.error);
    }
    if (committed) {
      await widget.app.audit('${widget.user['id']}', 'inventory', moveType, '${item['name']}');
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = Role.parse(widget.user['role']);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageIntro(title: 'إدارة المخزون والتجهيزات',
            subtitle: 'متابعة الأصناف والأرصدة وتسجيل الوارد والصرف والإرجاع للمراكز.',
            action: role.canEditOperations ? FilledButton.icon(onPressed: _addItem,
              icon: const Icon(Symbols.add), label: const Text('تجهيز جديد')) : null),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (value) {
                    _q = value;
                    _reload();
                  },
                  decoration: InputDecoration(
                    hintText: 'بحث باسم التجهيز',
                    prefixIcon: const Icon(Symbols.search),
                    suffixIcon: _q.isEmpty ? null : IconButton(
                      tooltip: 'مسح البحث', icon: const Icon(Symbols.close),
                      onPressed: () { _search.clear(); _q = ''; _reload(); }),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: _items,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return LoadFailure(message: 'تعذر تحميل بيانات المخزون.', onRetry: _reload);
                final items = snapshot.data ?? const <Map<String, Object?>>[];
                final totalQuantity = items.fold<int>(0,
                    (sum, item) => sum + ((item['quantity'] as int?) ?? 0));
                if (items.isEmpty) return EmptyState(_q.isEmpty
                    ? 'لا توجد تجهيزات مسجلة بعد. استخدم «تجهيز جديد» للبدء.'
                    : 'لا توجد تجهيزات تطابق عبارة البحث.');
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    SummaryMetric(label: 'عدد الأصناف', value: '${items.length}', icon: Symbols.inventory_2),
                    SummaryMetric(label: 'إجمالي الكميات', value: '$totalQuantity', icon: Symbols.inventory_2),
                  ]),
                  const SizedBox(height: 12),
                  Expanded(child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Symbols.inventory_2),
                        title: Text('${item['name']}'),
                        subtitle: Text('${item['category'] ?? '—'} • حالة: ${item['condition'] ?? '—'}'),
                        trailing: role.canEditOperations
                            ? Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                children: [
                                  Text('${item['quantity']} متاح', style: Theme.of(context).textTheme.titleSmall),
                                  PopupMenuButton<String>(
                                    tooltip: 'إجراءات التجهيز',
                                    onSelected: (value) => _move(item, value),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'in', child: Text('تسجيل وارد')),
                                      PopupMenuItem(value: 'issue', child: Text('صرف لمركز')),
                                      PopupMenuItem(value: 'return', child: Text('إرجاع من مركز')),
                                    ],
                                  ),
                                ],
                              )
                            : Text('${item['quantity']} متاح'),
                      ),
                    );
                  },
                  )),
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }
}
