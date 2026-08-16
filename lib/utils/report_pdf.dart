import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// توليد PDF للتقارير + مشاركته — بيعيد استخدام نص التقرير اللي بيطلّعه
/// report_formatter، وبيرسمه في PDF بخط يدعم العربي (Tajawal) عشان أسماء
/// المرضى العربي تظهر صح. مفيش مكتبة native (بيستخدم pdf pure-dart +
/// share_plus الموجودة أصلًا) — فمفيش أي مشاكل بناء على ويندوز.
pw.Font? _regular;
pw.Font? _bold;
pw.MemoryImage? _logo;

Future<void> _ensureFonts() async {
  _regular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
  _bold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
  if (_logo == null) {
    final bytes = await rootBundle.load('assets/images/app_logo.png');
    _logo = pw.MemoryImage(bytes.buffer.asUint8List());
  }
}

// خط Tajawal مافيهوش إيموجي — نستبدل رموز التقرير بنص قبل التوليد.
String _sanitize(String s) => s
    .replaceAll('👤 ', '')
    .replaceAll('👤', '')
    .replaceAll('✅', '[done] ')
    .replaceAll('❌', '[cancelled] ')
    .replaceAll('⬜', '[ ] ')
    .replaceAll('⚠️', '! ')
    .replaceAll('⚠', '! ')
    .replaceAll('❓', '? ')
    .replaceAll('📎', '')
    .replaceAll('🎤', '[voice] ')
    .replaceAll('📷', '[photo] ')
    .replaceAll('️', '')
    .replaceAll('‍', '')
    .replaceAll('​', '');

bool _isSeparator(String l) => RegExp(r'^[-=]{6,}$').hasMatch(l.trim());
bool _isCapsHeader(String l) {
  final t = l.trim();
  return t.length >= 3 && RegExp(r'^[A-Z][A-Z ]+$').hasMatch(t);
}

/// بيبني PDF من نص التقرير الجاهز (كل سطر بيتحوّل لسطر منسّق).
Future<Uint8List> buildReportPdf(String body) async {
  await _ensureFonts();
  final doc = pw.Document();
  final theme = pw.ThemeData.withFont(base: _regular!, bold: _bold!);
  final lines = _sanitize(body).replaceAll('\r', '').split('\n');

  final content = <pw.Widget>[
    pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
      pw.SizedBox(width: 32, height: 32, child: pw.Image(_logo!)),
      pw.SizedBox(width: 10),
      pw.Text('Awn Care', style: pw.TextStyle(font: _bold, fontSize: 17, color: PdfColors.blue900)),
    ]),
    pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6, bottom: 10),
      child: pw.Divider(height: 1, thickness: 0.7, color: PdfColors.blue200),
    ),
  ];
  var afterBreak = true; // أول سطر بعد فراغ/فاصل = اسم مريض (bold)
  var first = true; // أول سطر في التقرير = العنوان
  for (final line in lines) {
    if (line.trim().isEmpty) {
      content.add(pw.SizedBox(height: 6));
      afterBreak = true;
      continue;
    }
    if (_isSeparator(line)) {
      content.add(pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Divider(height: 1, thickness: 0.5, color: PdfColors.grey400),
      ));
      afterBreak = true;
      continue;
    }
    final caps = _isCapsHeader(line);
    final isName = afterBreak && !caps;
    afterBreak = false;

    final pw.TextStyle style;
    if (first) {
      style = pw.TextStyle(font: _bold, fontSize: 14, color: PdfColors.blue900);
    } else if (caps) {
      style = pw.TextStyle(font: _bold, fontSize: 10.5, color: PdfColors.blue800);
    } else if (isName) {
      style = pw.TextStyle(font: _bold, fontSize: 12);
    } else {
      style = pw.TextStyle(font: _regular, fontSize: 10.5, color: PdfColors.grey900);
    }
    first = false;
    content.add(pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.5),
      child: pw.Text(line, style: style),
    ));
  }

  doc.addPage(pw.MultiPage(
    theme: theme,
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(30, 30, 30, 26),
    footer: (ctx) => pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Awn Care · Page ${ctx.pageNumber}/${ctx.pagesCount}',
        style: pw.TextStyle(font: _regular, fontSize: 8, color: PdfColors.grey600),
      ),
    ),
    build: (ctx) => content,
  ));
  return doc.save();
}

/// بيبني الـ PDF، يحفظه في ملف مؤقت، ويفتح شيت المشاركة (حفظ/إرسال).
Future<void> shareReportPdf({
  required String subject,
  required String body,
  String filename = 'awn-care-report.pdf',
}) async {
  final bytes = await buildReportPdf(body);
  final dir = await getTemporaryDirectory();
  final safe = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');
  final file = File('${dir.path}/$safe');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(file.path)], subject: subject);
}
