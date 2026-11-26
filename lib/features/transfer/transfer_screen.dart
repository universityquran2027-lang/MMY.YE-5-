import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/db/app_database.dart';
import 'mmy_package.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key, required this.app, required this.user});
  final AppDatabase app;
  final Map<String, Object?> user;

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  bool _busy = false;
  String? _message;
  ImportSummary? _summary;
  File? _pendingImport;
  ConflictPolicy _policy = ConflictPolicy.keepLocal;
  bool _backup = true;

  Future<Directory> _temporaryDirectory() async =>
      Directory.systemTemp.createTemp('mmy-transfer');

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final temp = await _temporaryDirectory();
      final file = await MmyPackage(widget.app).export(targetDir: temp.path);
      final bytes = await file.readAsBytes();
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ ملف تصدير بيانات MMY',
        fileName: file.uri.pathSegments.last,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: const ['mmy'],
      );
      if (!mounted) return;
      setState(() => _message = saved == null
          ? 'تم إلغاء التصدير.'
          : 'تم تصدير البيانات بنجاح إلى:\n$saved');
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'تعذّر تصدير البيانات: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickImport() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'اختيار ملف بيانات MMY',
      type: FileType.custom,
      allowedExtensions: const ['mmy'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    final temp = await _temporaryDirectory();
    final file = File('${temp.path}/import.mmy');
    if (picked.bytes != null) {
      await file.writeAsBytes(picked.bytes!, flush: true);
    } else if (picked.path != null) {
      await File(picked.path!).copy(file.path);
    } else {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
      _summary = null;
    });
    try {
      final summary = await MmyPackage(widget.app).inspect(file);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _pendingImport = file;
        _message = 'تم فحص الملف بنجاح. راجع الملخص قبل الاستيراد.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'الملف غير صالح للاستيراد: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final manifest = _summary?.manifest;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text('تصدير واستيراد البيانات', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('النقل يدوي فقط ولا تتم أي مزامنة شبكية أو تلقائية.'),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _ActionCard(
                  icon: Symbols.file_export,
                  title: 'تصدير البيانات',
                  text: 'إنشاء ملف .mmy كامل يتضمن قاعدة البيانات والمرفقات.',
                  action: _busy ? null : _export,
                  buttonText: 'اختيار مكان الحفظ',
                ),
                _ActionCard(
                  icon: Symbols.file_open,
                  title: 'استيراد البيانات',
                  text: 'فحص ملف صادر ودمج بياناته مع البيانات المحلية.',
                  action: _busy ? null : _pickImport,
                  buttonText: 'اختيار ملف',
                ),
              ];
              final single = constraints.maxWidth < 760;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final card in cards)
                    SizedBox(width: single ? constraints.maxWidth : (constraints.maxWidth - 12) / 2, child: card),
                ],
              );
            },
          ),
          if (_summary != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ملخص الملف', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('تاريخ التصدير: ${manifest?['exported_at'] ?? '—'}'),
                    Text('إصدار التطبيق: ${manifest?['app_version'] ?? '—'}'),
                    Text('إصدار المخطط: ${manifest?['schema_version'] ?? '—'}'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in _summary!.tables.entries)
                          Chip(label: Text('${entry.key}: ${entry.value}')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ConflictPolicy>(
                      value: _policy,
                      decoration: const InputDecoration(labelText: 'طريقة معالجة التعارضات'),
                      items: const [
                        DropdownMenuItem(value: ConflictPolicy.keepLocal, child: Text('الإبقاء على البيانات المحلية')),
                        DropdownMenuItem(value: ConflictPolicy.useImported, child: Text('استبدالها بالبيانات المستوردة')),
                        DropdownMenuItem(value: ConflictPolicy.keepNewer, child: Text('الإبقاء على النسخة الأحدث')),
                      ],
                      onChanged: (value) => setState(() => _policy = value ?? ConflictPolicy.keepLocal),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('إنشاء نسخة احتياطية قبل الاستيراد'),
                      value: _backup,
                      onChanged: (value) => setState(() => _backup = value),
                    ),
                    FilledButton.icon(
                      onPressed: _busy ? null : _performImport,
                      icon: const Icon(Symbols.download),
                      label: const Text('بدء الاستيراد'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_busy) const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_message!),
            ),
        ],
      ),
    );
  }

  Future<void> _performImport() async {
    final file = _pendingImport;
    if (file == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final report = await MmyPackage(widget.app).import(
        file,
        policy: _policy,
        backupFirst: _backup,
      );
      if (!mounted) return;
      final inserted = report.inserted.values.fold<int>(0, (sum, value) => sum + value);
      final conflicts = report.conflicts.values.fold<int>(0, (sum, value) => sum + value);
      setState(() {
        _summary = null;
        _message = report.ok
            ? 'اكتمل الاستيراد بنجاح.\nالسجلات المضافة: $inserted\nالتعارضات المعالجة: $conflicts\nمسار النسخة الاحتياطية: ${report.backupPath ?? 'لا توجد'}'
            : 'فشل الاستيراد:\n${report.errors.join('\n')}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'تعذّر الاستيراد: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.action,
    required this.buttonText,
  });
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback? action;
  final String buttonText;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(text),
            const SizedBox(height: 14),
            FilledButton(onPressed: action, child: Text(buttonText)),
          ],
        ),
      ),
    );
  }
}
