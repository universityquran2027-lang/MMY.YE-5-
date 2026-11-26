import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/db/app_database.dart';
import '../../core/permissions.dart';
import '../../core/security/password_hasher.dart';
import '../../core/widgets.dart';
import '../transfer/transfer_screen.dart';
import '../inventory/inventory_screen.dart';
import '../reports/report_service.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key, required this.app, required this.user});
  final AppDatabase app;
  final Map<String, Object?> user;

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  int _tab = 0;
  int _reportYear = DateTime.now().year;
  int _reportMonth = DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    final role = Role.parse(widget.user['role']);
    final tabs = [
      ('الحسابات', Symbols.manage_accounts),
      ('الحماية', Symbols.shield),
      ('الإعدادات والهوية', Symbols.badge),
      ('صور النظرة العامة', Symbols.photo_library),
      ('المخزن والتجهيزات', Symbols.inventory_2),
      ('تصدير واستيراد', Symbols.swap_horiz),
      ('التقارير', Symbols.print),
      ('سجل التدقيق', Symbols.receipt_long),
      ('السجل الأمني', Symbols.security),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text('لوحة التحكم', style: Theme.of(context).textTheme.headlineSmall),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<int>(
            segments: [
              for (var i = 0; i < tabs.length; i++)
                ButtonSegment(
                  value: i,
                  icon: Icon(tabs[i].$2),
                  label: Text(tabs[i].$1),
                ),
            ],
            selected: {_tab},
            onSelectionChanged: (value) => setState(() => _tab = value.first),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: switch (_tab) {
            0 => _accounts(role),
            1 => _securityOverview(role),
            2 => _settings(role),
            3 => _placeholder(role),
            4 => InventoryScreen(app: widget.app, user: widget.user),
            5 => TransferScreen(app: widget.app, user: widget.user),
            6 => _reports(),
            7 => _auditLogs(role),
            8 => _securityLogs(role),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }

  Widget _accounts(Role role) {
    if (!role.canManageAccounts) {
      return const Center(child: Text('لا تملك صلاحية إدارة الحسابات.'));
    }
    return FutureBuilder<List<Map<String, Object?>>>(
      future: widget.app.db.query('users', orderBy: 'serial'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final users = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(child: Text('الحسابات الإدارية', style: Theme.of(context).textTheme.titleLarge)),
                if (users.length < 3)
                  FilledButton.icon(
                    onPressed: _addAccount,
                    icon: const Icon(Symbols.person_add),
                    label: const Text('إضافة حساب'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            for (final u in users)
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(Symbols.person)),
                  title: Text('${u['full_name']}'),
                  subtitle: Text('${u['username']} • ${_roleLabel('${u['role']}')}'),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      StatusChip('${u['status']}'),
                      PopupMenuButton<String>(
                        onSelected: (action) => _accountAction(u, action),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'password', child: Text('تغيير كلمة المرور')),
                          PopupMenuItem(
                            value: u['status'] == 'active' ? 'suspend' : 'activate',
                            child: Text(u['status'] == 'active' ? 'إيقاف الحساب' : 'إعادة تفعيل الحساب'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _roleLabel(String role) => switch (role) {
        'manager' => 'المدير',
        'assistant' => 'مساعد المدير',
        'archivist' => 'موظف الأرشيف',
        _ => role,
      };

  Future<void> _addAccount() async {
    final existing = await widget.app.db.query('users');
    final used = existing.map((u) => '${u['role']}').toSet();
    final options = <(String, String)>[
      if (!used.contains('assistant')) ('assistant', 'مساعد المدير'),
      if (!used.contains('archivist')) ('archivist', 'موظف الأرشيف'),
      if (!used.contains('manager')) ('manager', 'المدير'),
    ];
    if (options.isEmpty) return;
    final values = await showRecordForm(
      context,
      title: 'إضافة حساب إداري',
      fields: [
        const FieldSpec('full_name', 'الاسم الكامل', required: true),
        const FieldSpec('username', 'اسم المستخدم', required: true),
        const FieldSpec('password', 'كلمة المرور الابتدائية', required: true),
        FieldSpec('role', 'المنصب', type: FieldType.dropdown, required: true, options: options),
      ],
    );
    if (values == null) return;
    final roleName = values['role'] as String;
    final username = (values['username'] as String).trim();
    final password = values['password'] as String;
    final policyError = PasswordPolicy.validate(password, username: username);
    if (policyError != null) {
      toast(context, policyError);
      return;
    }
    final roleConflict = await widget.app.db.query('users', where: 'role = ?', whereArgs: [roleName], limit: 1);
    if (roleConflict.isNotEmpty) {
      toast(context, 'يوجد حساب مسنداً لهذا المنصب بالفعل.');
      return;
    }
    final t = nowIso();
    final id = newId();
    await widget.app.db.insert('users', {
      'id': id,
      'serial': existing.length + 1,
      'username': username,
      'password_hash': await PasswordHasher().hash(password),
      'full_name': values['full_name'],
      'role': roleName,
      'status': 'active',
      'must_change_password': 1,
      'created_at': t,
      'updated_at': t,
    });
    await widget.app.audit('${widget.user['id']}', 'users', 'add_account', username);
    if (mounted) setState(() {});
  }

  Future<void> _accountAction(Map<String, Object?> user, String action) async {
    final id = '${user['id']}';
    if (action == 'password') {
      final values = await showRecordForm(
        context,
        title: 'تغيير كلمة مرور ${user['full_name']}',
        fields: const [
          FieldSpec('password', 'كلمة المرور الجديدة', required: true),
          FieldSpec('confirm', 'تأكيد كلمة المرور', required: true),
        ],
      );
      if (values == null) return;
      if (values['password'] != values['confirm']) {
        toast(context, 'تأكيد كلمة المرور غير مطابق.');
        return;
      }
      final password = values['password'] as String;
      final policyError = PasswordPolicy.validate(password, username: '${user['username']}');
      if (policyError != null) {
        toast(context, policyError);
        return;
      }
      await widget.app.db.update(
        'users',
        {
          'password_hash': await PasswordHasher().hash(password),
          'must_change_password': 1,
          'failed_attempts': 0,
          'locked_until': null,
          'updated_at': nowIso(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await widget.app.audit('${widget.user['id']}', 'users', 'change_password', '${user['username']}');
    } else {
      final suspend = action == 'suspend';
      if (suspend && !await confirm(context, 'سيتم إيقاف الدخول لهذا الحساب مع الاحتفاظ بجميع بياناته وعملياته.')) {
        return;
      }
      await widget.app.db.update(
        'users',
        {'status': suspend ? 'suspended' : 'active', 'updated_at': nowIso()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await widget.app.audit('${widget.user['id']}', 'users', suspend ? 'suspend' : 'activate', '${user['username']}');
    }
    if (mounted) setState(() {});
  }


  Widget _reports() => FutureBuilder<List<Map<String, Object?>>>(
        future: widget.app.db.query('centers', orderBy: 'serial'),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _loadError('تعذر تحميل المراكز: ${snapshot.error}');
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final centers = snapshot.data!;
          if (centers.isEmpty) return const Center(child: Text('لا توجد مراكز لإنشاء التقارير.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('التقارير الشهرية', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text('اختر الفترة، ثم اطبع التقرير أو صدّره بصيغة PDF للمشاركة.'),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 8, children: [
                SizedBox(width: 150, child: DropdownButtonFormField<int>(
                  value: _reportMonth,
                  decoration: const InputDecoration(labelText: 'الشهر'),
                  items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text('$m'))],
                  onChanged: (v) => v == null ? null : setState(() => _reportMonth = v),
                )),
                SizedBox(width: 150, child: DropdownButtonFormField<int>(
                  value: _reportYear,
                  decoration: const InputDecoration(labelText: 'السنة'),
                  items: [for (var y = DateTime.now().year - 5; y <= DateTime.now().year + 1; y++) DropdownMenuItem(value: y, child: Text('$y'))],
                  onChanged: (v) => v == null ? null : setState(() => _reportYear = v),
                )),
              ]),
              const SizedBox(height: 12),
              for (final center in centers)
                Card(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Symbols.apartment),
                      title: Text('${center['name']}'),
                      subtitle: Text('${center['governorate'] ?? '—'} • $_reportMonth/$_reportYear'),
                    ),
                    Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [
                      OutlinedButton.icon(onPressed: () => _runReport(center, print: true), icon: const Icon(Symbols.print), label: const Text('طباعة')),
                      FilledButton.tonalIcon(onPressed: () => _runReport(center, print: false), icon: const Icon(Symbols.picture_as_pdf), label: const Text('تصدير PDF')),
                    ]),
                  ]),
                )),
            ],
          );
        },
      );

  Future<void> _runReport(Map<String, Object?> center, {required bool print}) async {
    final service = ReportService(widget.app);
    try {
      if (print) {
        await service.printCenterReport(centerId: '${center['id']}', year: _reportYear, month: _reportMonth);
        await widget.app.audit('${widget.user['id']}', 'reports', 'print_monthly_center', '${center['name']} • $_reportMonth/$_reportYear');
      } else {
        await service.shareCenterReport(centerId: '${center['id']}', centerName: '${center['name']}', year: _reportYear, month: _reportMonth);
        await widget.app.audit('${widget.user['id']}', 'reports', 'export_monthly_center_pdf', '${center['name']} • $_reportMonth/$_reportYear');
      }
    } catch (e) {
      if (mounted) toast(context, 'تعذر إنشاء التقرير: $e', kind: ToastKind.error);
    }
  }

  Widget _settings(Role role) => FutureBuilder<List<Map<String, Object?>>>(
        future: widget.app.db.query('settings', orderBy: 'key'),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _loadError('تعذر تحميل الإعدادات: ${snapshot.error}');
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snapshot.data!;
          final channelRows = rows.where((r) => r['key'] == 'channel_name').toList();
          final channel = channelRows.isEmpty ? null : channelRows.first;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('الإعدادات العامة والهوية', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('تُحفظ الإعدادات في قاعدة البيانات المحلية، ويُسجّل تعديلها في سجل التدقيق.'),
            const SizedBox(height: 12),
            Card(child: ListTile(
              leading: const Icon(Symbols.badge),
              title: const Text('اسم الجهة / القناة'),
              subtitle: Text('${channel?['value'] ?? 'الإعلام الحربي اليمني'}'),
              trailing: role.canManageAccounts ? IconButton(
                tooltip: 'تعديل',
                onPressed: () => _editSetting('channel_name', '${channel?['value'] ?? 'الإعلام الحربي اليمني'}'),
                icon: const Icon(Symbols.edit),
              ) : null,
            )),
            if (rows.length > 1) ...[
              const SizedBox(height: 8),
              Text('إعدادات أخرى', style: Theme.of(context).textTheme.titleMedium),
              for (final row in rows.where((r) => r['key'] != 'channel_name'))
                Card(child: ListTile(title: Text('${row['key']}'), subtitle: Text('${row['value'] ?? '—'}'))),
            ],
            if (!role.canManageAccounts) const Padding(padding: EdgeInsets.all(8), child: Text('التعديل متاح للمدير فقط.')),
          ]);
        },
      );

  Future<void> _editSetting(String key, String current) async {
    final values = await showRecordForm(context, title: 'تعديل اسم الجهة',
      fields: const [FieldSpec('value', 'اسم الجهة / القناة', required: true)], initial: {'value': current});
    if (values == null) return;
    final value = (values['value'] as String?)?.trim() ?? '';
    if (value.isEmpty) return;
    final now = nowIso();
    await widget.app.db.insert('settings', {'key': key, 'value': value, 'updated_at': now}, conflictAlgorithm: ConflictAlgorithm.replace);
    await widget.app.audit('${widget.user['id']}', 'settings', 'update', '$key: $current → $value');
    if (mounted) setState(() {});
  }

  Widget _securityOverview(Role role) {
    if (!role.canConfigureSecurity) return const Center(child: Text('لا تملك صلاحية الاطلاع على إعدادات الحماية.'));
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('إعدادات الحماية', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      const Card(child: ListTile(leading: Icon(Symbols.password), title: Text('محاولات الدخول الخاطئة'), subtitle: Text('يُقفل الحساب مؤقتاً بعد 5 محاولات متتالية.'))),
      const Card(child: ListTile(leading: Icon(Symbols.timer), title: Text('مدة القفل المؤقت'), subtitle: Text('15 دقيقة قبل السماح بمحاولة جديدة.'))),
      const Card(child: ListTile(leading: Icon(Symbols.lock_clock), title: Text('تغيير كلمة المرور'), subtitle: Text('يُطلب تغيير كلمة المرور الابتدائية عند أول دخول.'))),
      const SizedBox(height: 8),
      FilledButton.tonalIcon(onPressed: () => setState(() => _tab = 8), icon: const Icon(Symbols.security), label: const Text('عرض السجل الأمني')),
      const Padding(padding: EdgeInsets.only(top: 8), child: Text('هذه القيم ثابتة في سياسة الدخول الحالية؛ لا يتيح هذا القسم تغييرها لتجنب تغيير سلوك المصادقة دون مراجعة مستقلة.')),
    ]);
  }

  Widget _auditLogs(Role role) => _logList(
    role: role, title: 'سجل التدقيق',
    query: 'SELECT a.*, u.full_name AS actor_name, u.username AS actor_username FROM audit_log a LEFT JOIN users u ON u.id = a.user_id ORDER BY a.at DESC LIMIT 500',
    security: false,
  );

  Widget _securityLogs(Role role) => _logList(
    role: role, title: 'السجل الأمني',
    query: 'SELECT * FROM security_log ORDER BY at DESC LIMIT 500', security: true,
  );

  Widget _logList({required Role role, required String title, required String query, required bool security}) {
    if (!role.canManageAccounts) return const Center(child: Text('السجلات محمية ومتاحة للمدير فقط.'));
    return FutureBuilder<List<Map<String, Object?>>>(
      future: widget.app.db.rawQuery(query),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _loadError('تعذر تحميل $title: ${snapshot.error}');
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snapshot.data!;
        if (rows.isEmpty) return EmptyState('لا توجد سجلات في $title.');
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('عرض أحدث ${rows.length} سجل • السجلات للقراءة فقط ولا يمكن تعديلها أو حذفها.'),
          const SizedBox(height: 10),
          for (final row in rows)
            Card(child: ListTile(
              leading: Icon(security ? Symbols.shield : Symbols.history),
              title: Text(security ? _securityEventLabel('${row['event']}') : '${row['section']} • ${row['action']}'),
              subtitle: Text([
                if (security) 'المستخدم: ${row['username'] ?? '—'}' else 'بواسطة: ${row['actor_name'] ?? row['actor_username'] ?? 'حساب غير معروف'}',
                if ('${row['details'] ?? ''}'.isNotEmpty) '${row['details']}',
                _formatLogTime('${row['at']}'),
              ].join('\n')),
              isThreeLine: true,
            )),
        ]);
      },
    );
  }

  String _securityEventLabel(String event) => switch (event) {
    'login_ok' => 'تسجيل دخول ناجح', 'login_failed' => 'محاولة دخول فاشلة',
    'login_blocked' => 'محاولة دخول محظورة', 'account_locked' => 'قفل الحساب مؤقتاً',
    'password_changed' => 'تغيير كلمة المرور', 'default_admin_created' => 'إنشاء حساب المدير الافتراضي',
    _ => event,
  };

  String _formatLogTime(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
  }

  Widget _loadError(String message) => Center(child: Padding(
    padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Symbols.error, size: 36), const SizedBox(height: 8),
      Text(message, textAlign: TextAlign.center), const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: () => setState(() {}), icon: const Icon(Symbols.refresh), label: const Text('إعادة المحاولة')),
    ]),
  ));


  Widget _placeholder(Role role) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Card(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('صور النظرة العامة', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('إدارة الصور وترتيبها واستبدالها تحتاج واجهة مخصصة. لم نضف عمليات حذف أو تعديل للملفات المرتبطة بالسجلات.'),
          const SizedBox(height: 12),
          Text(role.canManageAccounts ? 'هذه الوظيفة لم تُفعّل في هذه المرحلة.' : 'لا تملك صلاحية إدارة هذه النافذة.',
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ]),
      )),
    ),
  );

}
