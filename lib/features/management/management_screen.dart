import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/db/app_database.dart';
import '../../core/permissions.dart';
import '../../core/widgets.dart';

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key, required this.app, required this.user});
  final AppDatabase app;
  final Map<String, Object?> user;

  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  late Future<List<Map<String, Object?>>> _profiles;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() {
        _profiles = widget.app.db.rawQuery('''
          SELECT u.*, p.birth_date, p.phone, p.address, p.department, p.start_date,
                 p.job_status, p.responsibilities, p.courses, p.qualifications, p.experience
          FROM users u LEFT JOIN admin_profiles p ON p.user_id = u.id
          ORDER BY u.serial
        ''');
      });

  Future<void> _edit(Map<String, Object?> u) async {
    final role = Role.parse(widget.user['role']);
    if (!role.canManageAccounts) return;
    final values = await showRecordForm(
      context,
      title: 'ملف ${u['full_name']}',
      fields: const [
        FieldSpec('full_name', 'الاسم الكامل', required: true),
        FieldSpec('birth_date', 'تاريخ الميلاد', type: FieldType.date),
        FieldSpec('phone', 'رقم الجوال', type: FieldType.phone),
        FieldSpec('address', 'العنوان', type: FieldType.multiline),
        FieldSpec('department', 'القسم المسؤول عنه'),
        FieldSpec('start_date', 'تاريخ استلام المنصب', type: FieldType.date),
        FieldSpec('job_status', 'الحالة الوظيفية'),
        FieldSpec('responsibilities', 'المهام والمسؤوليات', type: FieldType.multiline),
        FieldSpec('courses', 'الدورات التدريبية', type: FieldType.multiline),
        FieldSpec('qualifications', 'المؤهلات العلمية', type: FieldType.multiline),
        FieldSpec('experience', 'الخبرات السابقة', type: FieldType.multiline),
      ],
      initial: u,
    );
    if (values == null) return;
    final t = nowIso();
    await widget.app.db.update(
      'users',
      {'full_name': values['full_name'], 'updated_at': t},
      where: 'id = ?',
      whereArgs: [u['id']],
    );
    final profile = await widget.app.db.query(
      'admin_profiles',
      where: 'user_id = ?',
      whereArgs: [u['id']],
      limit: 1,
    );
    final data = {
      'birth_date': values['birth_date'],
      'phone': values['phone'],
      'address': values['address'],
      'department': values['department'],
      'start_date': values['start_date'],
      'job_status': values['job_status'],
      'responsibilities': values['responsibilities'],
      'courses': values['courses'],
      'qualifications': values['qualifications'],
      'experience': values['experience'],
      'updated_at': t,
    };
    if (profile.isEmpty) {
      await widget.app.db.insert('admin_profiles', {
        'id': newId(),
        'user_id': u['id'],
        ...data,
      });
    } else {
      await widget.app.db.update(
        'admin_profiles',
        data,
        where: 'user_id = ?',
        whereArgs: [u['id']],
      );
    }
    await widget.app.audit('${widget.user['id']}', 'management', 'edit_profile', '${u['full_name']}');
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final role = Role.parse(widget.user['role']);
    return FutureBuilder<List<Map<String, Object?>>>(
      future: _profiles,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final profiles = snapshot.data!;
        if (profiles.isEmpty) return const EmptyState('لا توجد ملفات إدارية.');
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 380,
            mainAxisExtent: 210,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: profiles.length,
          itemBuilder: (context, index) {
            final u = profiles[index];
            return Card(
              child: InkWell(
                onTap: role.canManageAccounts ? () => _edit(u) : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            child: const Icon(Symbols.person),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${u['full_name']}', style: Theme.of(context).textTheme.titleMedium),
                                Text(_roleLabel('${u['role']}')),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('رقم الهاتف: ${u['phone'] ?? '—'}'),
                      Text('القسم: ${u['department'] ?? '—'}'),
                      const Spacer(),
                      if (role.canManageAccounts)
                        TextButton.icon(
                          onPressed: () => _edit(u),
                          icon: const Icon(Symbols.edit),
                          label: const Text('فتح الملف'),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
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
}
