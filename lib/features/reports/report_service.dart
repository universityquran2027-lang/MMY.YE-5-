import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/db/app_database.dart';

class ReportService {
  ReportService(this.app);
  final AppDatabase app;

  Future<Uint8List> buildMonthlyCenterReport({
    required String centerId,
    required int year,
    required int month,
  }) async {
    if (month < 1 || month > 12) throw ArgumentError.value(month, 'month');
    final centerRows = await app.db.query(
      'centers', where: 'id = ?', whereArgs: [centerId], limit: 1,
    );
    if (centerRows.isEmpty) throw Exception('المركز غير موجود');
    final center = centerRows.first;
    final channelRows = await app.db.query('settings', where: 'key = ?', whereArgs: ['channel_name'], limit: 1);
    final channelName = channelRows.isEmpty ? 'الإعلام الحربي اليمني' : '${channelRows.first['value'] ?? 'الإعلام الحربي اليمني'}';
    final from = DateTime.utc(year, month, 1).toIso8601String().substring(0, 10);
    final until = DateTime.utc(year, month + 1, 1).toIso8601String().substring(0, 10);

    final evaluations = await app.db.query(
      'evaluations',
      where: 'center_id = ? AND year = ? AND month = ?',
      whereArgs: [centerId, year, month],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    final tasks = await app.db.rawQuery('''
      SELECT * FROM field_tasks
      WHERE center_id = ?
        AND date(COALESCE(NULLIF(actual_start, ''), NULLIF(start_date, ''), created_at)) >= date(?)
        AND date(COALESCE(NULLIF(actual_start, ''), NULLIF(start_date, ''), created_at)) < date(?)
      ORDER BY COALESCE(NULLIF(actual_start, ''), NULLIF(start_date, ''), created_at) DESC
    ''', [centerId, from, until]);
    final staff = await app.db.query(
      'media_staff', where: 'center_id = ? AND status = ?',
      whereArgs: [centerId, 'active'], orderBy: 'serial',
    );
    final delivered = await app.db.rawQuery('''
      SELECT COUNT(*) AS total,
             COALESCE(SUM(CASE WHEN size_unit = 'MB' THEN size_value ELSE 0 END), 0) AS size_mb,
             COALESCE(SUM(CASE WHEN size_unit = 'GB' THEN size_value ELSE 0 END), 0) AS size_gb
      FROM delivered_materials
      WHERE center_id = ? AND delivered_at IS NOT NULL
        AND date(delivered_at) >= date(?) AND date(delivered_at) < date(?)
    ''', [centerId, from, until]);

    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoNaskhArabic-Bold.ttf'));
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
    final taskRows = <pw.TableRow>[
      _tableRow(['المهمة', 'النوع', 'الحالة', 'الإنجاز'], bold: true),
      for (final task in tasks)
        _tableRow([
          '${task['title'] ?? '—'}',
          '${task['task_type'] ?? '—'}',
          _taskStatus('${task['status']}'),
          '${task['progress_percent'] ?? 0}%',
        ]),
    ];

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => [
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.green900, width: 1.5),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Column(children: [
                pw.Text(channelName, style: pw.TextStyle(font: bold, fontSize: 18, color: PdfColors.green900)),
                pw.SizedBox(height: 5),
                pw.Text('التقرير الشهري للمركز', style: pw.TextStyle(font: bold, fontSize: 15)),
              ]),
            ),
            pw.SizedBox(height: 14),
            _infoLine('اسم المركز', '${center['name'] ?? '—'}'),
            _infoLine('المحافظة', '${center['governorate'] ?? '—'}'),
            _infoLine('الفترة', '$month / $year'),
            pw.SizedBox(height: 10),
            pw.Wrap(spacing: 8, runSpacing: 8, children: [
              _metric('الإعلاميون النشطون حالياً', '${staff.length}'),
              _metric('المهام خلال الشهر', '${tasks.length}'),
              _metric('المواد المسلّمة', '${delivered.first['total'] ?? 0}'),
              _metric('حجم المواد (MB / GB)', '${delivered.first['size_mb'] ?? 0} / ${delivered.first['size_gb'] ?? 0}'),
            ]),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              color: PdfColors.grey100,
              child: pw.Text(
                evaluations.isEmpty
                    ? 'نتيجة التقييم: لم يعتمد تقييم لهذه الفترة'
                    : 'نتيجة التقييم: ${evaluations.first['total_score'] ?? '—'}%',
                style: pw.TextStyle(font: bold, fontSize: 13),
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text('المهام الميدانية خلال الفترة', style: pw.TextStyle(font: bold, fontSize: 13)),
            pw.SizedBox(height: 7),
            if (tasks.isEmpty)
              pw.Text('لا توجد مهام مسجلة خلال هذه الفترة.')
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(1.6), 3: pw.FlexColumnWidth(1.2),
                },
                children: taskRows,
              ),
            pw.SizedBox(height: 18),
            pw.Text('أُنشئ هذا التقرير من بيانات النظام المسجلة حتى وقت التصدير.',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ]),
        ),
      ],
    ));
    return pdf.save();
  }

  pw.TableRow _tableRow(List<String> cells, {bool bold = false}) => pw.TableRow(
    children: [
      for (final cell in cells)
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Text(cell, style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ),
        ),
    ],
  );

  pw.Widget _infoLine(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(children: [
      pw.SizedBox(width: 90, child: pw.Text('$label:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
      pw.Expanded(child: pw.Text(value)),
    ]),
  );

  pw.Widget _metric(String label, String value) => pw.Container(
    width: 118,
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(color: PdfColors.green50, borderRadius: pw.BorderRadius.circular(4)),
    child: pw.Column(children: [
      pw.Text(value, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
      pw.SizedBox(height: 3),
      pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
    ]),
  );

  String _taskStatus(String status) => switch (status) {
    'planned' => 'مخططة', 'running' => 'جارية', 'done' => 'منتهية',
    'cancelled' => 'ملغية', _ => status,
  };

  Future<void> printCenterReport({
    required String centerId, required int year, required int month,
  }) async {
    final bytes = await buildMonthlyCenterReport(centerId: centerId, year: year, month: month);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<File> exportCenterReport({
    required String centerId,
    required String centerName,
    required int year,
    required int month,
  }) async {
    final bytes = await buildMonthlyCenterReport(centerId: centerId, year: year, month: month);
    final dir = await getTemporaryDirectory();
    final safeName = centerName.replaceAll(RegExp(r'[^\u0600-\u06FFa-zA-Z0-9_-]+'), '_');
    final file = File(p.join(dir.path, 'report-$safeName-$year-${month.toString().padLeft(2, '0')}.pdf'));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> shareCenterReport({
    required String centerId, required String centerName,
    required int year, required int month,
  }) async {
    final file = await exportCenterReport(
      centerId: centerId, centerName: centerName, year: year, month: month,
    );
    await Share.shareXFiles([XFile(file.path)], text: 'التقرير الشهري للمركز: $centerName');
  }
}
