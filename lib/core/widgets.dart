import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'brand.dart';
import 'permissions.dart'; // statusLabels

enum FieldType { text, phone, multiline, date, dropdown, integer, decimal }

class FieldSpec {
  const FieldSpec(this.key, this.label,
      {this.type = FieldType.text, this.required = false, this.options = const []});
  final String key, label;
  final FieldType type;
  final bool required;
  final List<(String value, String label)> options; // للقوائم المنسدلة
}

/// نافذة نموذج عامة (إضافة/تعديل) مع تحقق من الحقول الإلزامية واختيار التواريخ.
/// على الهاتف تُعرض بملء الشاشة، وعلى الحاسوب/اللوح كنافذة مركزية بعرض مريح.
Future<Map<String, Object?>?> showRecordForm(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  Map<String, Object?> initial = const {},
}) {
  return showDialog<Map<String, Object?>>(
    context: context,
    barrierDismissible: false, // يمنع فقد ما كُتب بلمسة خارج النافذة
    builder: (_) => _RecordForm(title: title, fields: fields, initial: initial),
  );
}

class _RecordForm extends StatefulWidget {
  const _RecordForm({required this.title, required this.fields, required this.initial});
  final String title;
  final List<FieldSpec> fields;
  final Map<String, Object?> initial;
  @override
  State<_RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<_RecordForm> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  late final Map<String, String?> _drop;

  @override
  void initState() {
    super.initState();
    _c = {for (final f in widget.fields) f.key: TextEditingController(text: '${widget.initial[f.key] ?? ''}')};
    _drop = {for (final f in widget.fields.where((f) => f.type == FieldType.dropdown))
      f.key: widget.initial[f.key] as String? ?? (f.required ? null : '')};
  }

  @override
  void dispose() {
    for (final controller in _c.values) { controller.dispose(); }
    super.dispose();
  }

  Future<void> _pickDate(FieldSpec f) async {
    final cur = DateTime.tryParse(_c[f.key]!.text) ?? DateTime.now();
    final d = await showDatePicker(
        context: context, initialDate: cur, firstDate: DateTime(1950), lastDate: DateTime(2100));
    if (d != null) _c[f.key]!.text = d.toIso8601String().substring(0, 10);
  }

  String _label(FieldSpec f) => f.required ? '${f.label} *' : f.label;

  Widget _field(FieldSpec f) {
    String? req(String? v) => f.required && (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null;
    switch (f.type) {
      case FieldType.dropdown:
        return DropdownButtonFormField<String>(
          value: _drop[f.key] == '' ? null : _drop[f.key],
          isExpanded: true,
          decoration: InputDecoration(labelText: _label(f)),
          items: [for (final o in f.options) DropdownMenuItem(value: o.$1, child: Text(o.$2))],
          onChanged: (v) => setState(() => _drop[f.key] = v),
          validator: (v) => f.required && v == null ? 'هذا الحقل مطلوب' : null,
        );
      case FieldType.date:
        return TextFormField(
          controller: _c[f.key], readOnly: true, onTap: () => _pickDate(f),
          decoration: InputDecoration(labelText: _label(f), suffixIcon: const Icon(Symbols.calendar_today)),
          validator: req,
        );
      case FieldType.phone:
        return TextFormField(
          controller: _c[f.key], keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: _label(f), prefixIcon: const Icon(Symbols.call)),
          validator: (v) {
            final r = req(v);
            if (r != null) return r;
            if (v != null && v.trim().isNotEmpty && !RegExp(r'^[+0-9\s-]{6,20}$').hasMatch(v.trim())) {
              return 'رقم هاتف غير صالح';
            }
            return null;
          },
        );
      case FieldType.multiline:
        return TextFormField(controller: _c[f.key], minLines: 2, maxLines: 5,
            decoration: InputDecoration(labelText: _label(f)), validator: req);
      case FieldType.integer:
      case FieldType.decimal:
        return TextFormField(
          controller: _c[f.key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
          decoration: InputDecoration(labelText: _label(f)),
          validator: (v) {
            final r = req(v);
            if (r != null) return r;
            if (v != null && v.trim().isNotEmpty) {
              final valid = f.type == FieldType.integer
                  ? RegExp(r'^\d+$').hasMatch(v.trim())
                  : RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(v.trim());
              if (!valid) return f.type == FieldType.integer
                  ? 'أدخل رقماً صحيحاً موجباً.'
                  : 'أدخل رقماً صحيحاً أو عشرياً (حتى منزلتين).';
            }
            return null;
          },
        );
      case FieldType.text:
        return TextFormField(controller: _c[f.key], decoration: InputDecoration(labelText: _label(f)), validator: req);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final out = <String, Object?>{};
    for (final f in widget.fields) {
      final v = f.type == FieldType.dropdown ? (_drop[f.key] ?? '') : _c[f.key]!.text.trim();
      out[f.key] = v.isEmpty ? null : v;
    }
    Navigator.pop(context, out);
  }

  IconData get _headerIcon {
    final t = widget.title;
    if (t.contains('إضافة') || t.contains('إنشاء') || t.contains('جديد')) return Symbols.add_circle;
    if (t.contains('تعديل')) return Symbols.edit;
    return Symbols.edit_note;
  }

  Widget _form() => Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(children: [
          for (final f in widget.fields)
            Padding(padding: const EdgeInsets.only(bottom: 14), child: _field(f)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screen = MediaQuery.sizeOf(context);

    // الهاتف: صفحة كاملة بشريط علوي وزر حفظ ثابت أسفل الشاشة (يظهر فوق لوحة المفاتيح).
    if (screen.width < 600) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'إغلاق',
              icon: const Icon(Symbols.close),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(widget.title),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: _form(),
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(top: BorderSide(color: cs.outline.withValues(alpha: .6))),
              ),
              child: Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء'))),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(onPressed: _save, icon: const Icon(Symbols.check), label: const Text('حفظ')),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    // الحاسوب واللوح: نافذة مركزية.
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: screen.height * .88),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(22, 16, 12, 14),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(13)),
                child: Icon(_headerIcon, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.titleLarge)),
              IconButton(tooltip: 'إغلاق', icon: const Icon(Symbols.close), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
              child: _form(),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              const SizedBox(width: 8),
              FilledButton.icon(onPressed: _save, icon: const Icon(Symbols.check), label: const Text('حفظ')),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// نافذة تأكيد للإجراءات الحساسة (حذف/إيقاف). تُرجع true عند التأكيد.
Future<bool> confirm(BuildContext context, String message, {String action = 'حذف'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final text = Theme.of(ctx).textTheme;
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(color: cs.error.withValues(alpha: .12), shape: BoxShape.circle),
                child: Icon(action == 'حذف' ? Symbols.delete : Symbols.warning, color: cs.error, size: 32),
              ),
              const SizedBox(height: 16),
              Text('تأكيد الإجراء', style: text.titleLarge),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: .75))),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء'))),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(action),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      );
    },
  );
  return r ?? false;
}

enum ToastKind { info, success, warning, error }

/// تنبيه عائم قصير. الافتراضي «تنبيه» لأن معظم الاستدعاءات رسائل تحقق/صلاحيات.
void toast(BuildContext c, String m, {ToastKind kind = ToastKind.warning}) {
  final (icon, color) = switch (kind) {
    ToastKind.success => (Symbols.check_circle, const Color(0xFF2EAD66)),
    ToastKind.error => (Symbols.error, const Color(0xFFE5484D)),
    ToastKind.warning => (Symbols.warning, const Color(0xFFE59A12)),
    ToastKind.info => (Symbols.info, const Color(0xFF3B8EDB)),
  };
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: Duration(seconds: kind == ToastKind.error ? 5 : 3),
      content: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(m)),
      ]),
    ));
}

/// شارة حالة بنقطة لونية. الألوان: نشط/منتهية أخضر، جارية أزرق، مخططة كهرماني،
/// متوقف/ملغية/موقوف أحمر، وغيرها رمادي.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  (Color fg, Color bg) _colors(ColorScheme cs) {
    final dark = cs.brightness == Brightness.dark;
    switch (status) {
      case 'active':
      case 'done':
        return (dark ? const Color(0xFF7FD8A2) : Brand.green, cs.primary.withValues(alpha: .14));
      case 'running':
        return (dark ? const Color(0xFF8FC4F2) : const Color(0xFF165A98), Brand.info.withValues(alpha: .14));
      case 'planned':
        return (dark ? const Color(0xFFF3C46B) : const Color(0xFF8A5A00), Brand.warning.withValues(alpha: .16));
      case 'stopped':
      case 'cancelled':
      case 'suspended':
        return (cs.error, cs.error.withValues(alpha: .12));
      default:
        return (cs.onSurface.withValues(alpha: .7), cs.onSurface.withValues(alpha: .08));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = _colors(Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(statusLabels[status] ?? status,
            style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key, this.icon = Symbols.inbox});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: .7), shape: BoxShape.circle),
            child: Icon(icon, size: 34, color: cs.primary),
          ),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: .72))),
        ]),
      ),
    );
  }
}

/// عنوان موحد للأقسام الداخلية مع وصف مختصر وإجراء اختياري.
class PageIntro extends StatelessWidget {
  const PageIntro({super.key, required this.title, required this.subtitle, this.action});
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(builder: (context, constraints) {
        final heading = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: .65))),
        ]);
        if (action == null) return heading;
        if (constraints.maxWidth < 560) return Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [heading, const SizedBox(height: 12), action!]);
        return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: heading), const SizedBox(width: 12), action!,
        ]);
      }),
    );
  }
}

/// شبكة موحدة لعرض بيانات السجلات بشكل مريح على الهاتف والحاسوب.
class DetailGrid extends StatelessWidget {
  const DetailGrid({super.key, required this.items});
  final List<(String, Object?)> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final wide = constraints.maxWidth >= 720;
    final width = wide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final item in items)
            SizedBox(
              width: width,
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.$1, style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: .62))),
                    const SizedBox(height: 5),
                    Text('${item.$2 ?? '—'}', style: Theme.of(context).textTheme.bodyLarge,
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  });
}

/// بطاقة رقمية صغيرة تستخدم في ملخصات الصفحات.
class SummaryMetric extends StatelessWidget {
  const SummaryMetric({super.key, required this.label, required this.value,
    required this.icon, this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = color ?? cs.primary;
    return Card(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: accent, size: 22)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurface.withValues(alpha: .65))),
        ]),
      ]),
    ));
  }
}

/// حالة تحميل/خطأ موحدة مع إمكانية إعادة المحاولة.
class LoadFailure extends StatelessWidget {
  const LoadFailure({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(child: Padding(
      padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: cs.error.withValues(alpha: .1), shape: BoxShape.circle),
          child: Icon(Symbols.cloud_off, size: 34, color: cs.error),
        ),
        const SizedBox(height: 14), Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 14), OutlinedButton.icon(onPressed: onRetry,
          icon: const Icon(Symbols.refresh), label: const Text('إعادة المحاولة')),
      ]),
    ));
  }
}
