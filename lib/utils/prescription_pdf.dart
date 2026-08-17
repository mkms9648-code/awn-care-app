import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/patient_summary.dart';
import 'ticket_utils.dart';

/// روشتة (Rx) منفصلة عن التقرير العام — تصميم مخصص لصفحة دوا فعلية بدل
/// سطور نص عادية: هيدر لوجو مركزي صغير، بيانات مريض في بوكس، تحذير حساسية
/// بارز لو موجود، وقائمة أدوية مرقّمة بخط واضح.
///
/// [PrescriptionLanguage.arabic]: **بس** سطر جرعة/طريقة/تكرار كل دواء
/// والتعليمات بيتحولوا عربي (نص حقيقي مترجم عن طريق [TranslationService]،
/// مبعوت جاهز هنا في [translatedDoseLines]/[translatedInstructions] —
/// الملف ده مش بيترجم حاجة بنفسه). أي حاجة تانية (اسم الدواء، بيانات
/// المريض، العناوين الثابتة) بتفضل انجليزي زي ما هي في الحالتين — قرار
/// صريح من صاحب المنتج.
enum PrescriptionLanguage { english, arabic }

const _brandBlue = PdfColor.fromInt(0xFF3B6FF2);
const _brandBlueDeep = PdfColor.fromInt(0xFF0A2540);
const _brandBlueLight = PdfColor.fromInt(0xFFE8F3FF);

pw.Font? _regular;
pw.Font? _bold;
pw.MemoryImage? _logo;

Future<void> _ensureAssets() async {
  _regular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
  _bold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
  if (_logo == null) {
    final bytes = await rootBundle.load('assets/images/app_logo.png');
    _logo = pw.MemoryImage(bytes.buffer.asUint8List());
  }
}

final _dateFmt = DateFormat('dd MMM yyyy');
final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');

pw.Widget _brandMark() {
  return pw.Column(
    children: [
      pw.SizedBox(width: 30, height: 30, child: pw.Image(_logo!)),
      pw.SizedBox(height: 3),
      pw.Text(
        'AWN CARE',
        style: pw.TextStyle(font: _bold, fontSize: 7.5, color: _brandBlueDeep, letterSpacing: 1.4),
      ),
    ],
  );
}

pw.Widget _infoRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 62,
          child: pw.Text(label, style: pw.TextStyle(font: _regular, fontSize: 8.5, color: PdfColors.grey600)),
        ),
        pw.Expanded(
          child: pw.Text(value, style: pw.TextStyle(font: _bold, fontSize: 10, color: _brandBlueDeep)),
        ),
      ],
    ),
  );
}

/// النص العربي المفرد ده بيتلف RTL لوحده جوه سياق الصفحة العادي (LTR) —
/// الصفحة نفسها بتفضل بنفس شكلها الانجليزي بالظبط.
pw.Widget _maybeRtl(String text, pw.TextStyle style, {bool rtl = false}) {
  final child = pw.Text(text, style: style);
  return rtl ? pw.Directionality(textDirection: pw.TextDirection.rtl, child: child) : child;
}

/// بيبني PDF روشتة لقائمة أدوية فعالة — مفيش استدعاء ليها لو القائمة فاضية،
/// الكارتر (patient_detail_screen) بيتأكد من كده الأول.
///
/// [instructions]: تعليمات المريض (kind='health_education')، بتتحط تحت
/// الأدوية لو موجودة.
/// [translatedDoseLines] / [translatedInstructions]: النسخة العربية
/// الجاهزة (لو [language] == arabic) — بنفس ترتيب [summary.activeMedications]
/// و [instructions] بالظبط. لو null أو أقصر من المتوقع، السطر المقابل
/// بيرجع للانجليزي الأصلي بدل ما يتمسح.
Future<Uint8List> buildPrescriptionPdf(
  PatientSummary summary, {
  List<NoteHistoryEntry> instructions = const [],
  PrescriptionLanguage language = PrescriptionLanguage.english,
  List<String>? translatedDoseLines,
  List<String>? translatedInstructions,
}) async {
  await _ensureAssets();
  final doc = pw.Document();
  final theme = pw.ThemeData.withFont(base: _regular!, bold: _bold!);
  final ar = language == PrescriptionLanguage.arabic;

  final p = summary.patient;
  final e = summary.encounter;
  final meds = summary.activeMedications;
  final ticket = e.handle != null ? cleanTicket(e.handle!) : null;
  final ageLine = p.birthYear != null ? '${DateTime.now().year - p.birthYear!} yrs' : '—';
  final sexLine = p.sex == 'm' ? 'Male' : (p.sex == 'f' ? 'Female' : '—');
  final now = DateTime.now();

  String doseLine(int i) {
    final original = [meds[i].dose, meds[i].route, meds[i].frequency]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join('  ·  ');
    if (ar && translatedDoseLines != null && i < translatedDoseLines.length && translatedDoseLines[i].isNotEmpty) {
      return translatedDoseLines[i];
    }
    return original;
  }

  String instructionText(int i) {
    if (ar &&
        translatedInstructions != null &&
        i < translatedInstructions.length &&
        translatedInstructions[i].isNotEmpty) {
      return translatedInstructions[i];
    }
    return instructions[i].body;
  }

  doc.addPage(
    pw.MultiPage(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(34, 30, 34, 26),
      build: (ctx) => [
          // ===== Header: small centered brand mark =====
          pw.Center(child: _brandMark()),
          pw.SizedBox(height: 14),
          pw.Container(height: 2, color: _brandBlue),
          pw.SizedBox(height: 18),

          // ===== Title row =====
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('℞', style: pw.TextStyle(font: _bold, fontSize: 30, color: _brandBlue)),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Text(
                  'Prescription',
                  style: pw.TextStyle(font: _bold, fontSize: 19, color: _brandBlueDeep),
                ),
              ),
              pw.Text(
                _dateFmt.format(now),
                style: pw.TextStyle(font: _regular, fontSize: 9.5, color: PdfColors.grey600),
              ),
            ],
          ),
          pw.SizedBox(height: 18),

          // ===== Patient info box — يفضل انجليزي دايمًا في الحالتين =====
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: _brandBlueLight,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _infoRow('Patient', p.name),
                      _infoRow('MRN', p.mrn),
                      if (ticket != null) _infoRow('Ticket', '#$ticket'),
                    ],
                  ),
                ),
                pw.SizedBox(width: 18),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _infoRow('Age / Sex', '$ageLine · $sexLine'),
                      if (e.unit != null) _infoRow('Unit', e.unit!),
                      if (e.attending != null) _infoRow('Attending', 'Dr. ${e.attending}'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ===== Allergy warning =====
          if (p.allergies.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: pw.BoxDecoration(
                color: PdfColors.red50,
                border: pw.Border.all(color: PdfColors.red300, width: 0.8),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'ALLERGIES: ${p.allergies.join(', ')}',
                style: pw.TextStyle(font: _bold, fontSize: 9.5, color: PdfColors.red900),
              ),
            ),
          ],

          pw.SizedBox(height: 22),

          // ===== Rx list — اسم الدواء يفضل انجليزي دايمًا، سطر الجرعة/
          // الطريقة/التكرار بس هو اللي بيتحول عربي لو مطلوب =====
          for (var i = 0; i < meds.length; i++) ...[
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 10),
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.7)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 20,
                    height: 20,
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: _brandBlue),
                    child: pw.Text(
                      '${i + 1}',
                      style: pw.TextStyle(font: _bold, fontSize: 9.5, color: PdfColors.white),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          meds[i].name,
                          style: pw.TextStyle(font: _bold, fontSize: 12.5, color: _brandBlueDeep),
                        ),
                        if (doseLine(i).isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          _maybeRtl(
                            doseLine(i),
                            pw.TextStyle(font: _regular, fontSize: 10, color: PdfColors.grey700),
                            rtl: ar,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ===== Patient instructions — دي اللي بتتحول عربي فعليًا =====
          if (instructions.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Instructions',
              style: pw.TextStyle(font: _bold, fontSize: 12.5, color: _brandBlueDeep),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: _brandBlueLight,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < instructions.length; i++)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('•  ', style: pw.TextStyle(font: _bold, fontSize: 10, color: _brandBlue)),
                          pw.Expanded(
                            child: _maybeRtl(
                              instructionText(i),
                              pw.TextStyle(font: _regular, fontSize: 10),
                              rtl: ar,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          // ===== Signature =====
          pw.SizedBox(height: 40),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(width: 160, height: 0.8, color: PdfColors.grey500),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    e.attending != null ? 'Dr. ${e.attending}' : 'Physician signature',
                    style: pw.TextStyle(font: _bold, fontSize: 9.5, color: _brandBlueDeep),
                  ),
                ],
              ),
            ],
          ),
        ],
      footer: (ctx) => pw.Column(
        children: [
          pw.SizedBox(height: 6),
          pw.Text(
            'Generated via Awn Care on ${_dateTimeFmt.format(now)} — reflects the physician\'s documented active medications.',
            style: pw.TextStyle(font: _regular, fontSize: 7, color: PdfColors.grey500),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    ),
  );

  return doc.save();
}

Future<void> sharePrescriptionPdf(
  PatientSummary summary, {
  List<NoteHistoryEntry> instructions = const [],
  PrescriptionLanguage language = PrescriptionLanguage.english,
  List<String>? translatedDoseLines,
  List<String>? translatedInstructions,
}) async {
  final bytes = await buildPrescriptionPdf(
    summary,
    instructions: instructions,
    language: language,
    translatedDoseLines: translatedDoseLines,
    translatedInstructions: translatedInstructions,
  );
  final dir = await getTemporaryDirectory();
  final safeName = summary.patient.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');
  final file = File('${dir.path}/awn-care-rx-$safeName.pdf');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles(
    [XFile(file.path)],
    subject: 'Prescription — ${summary.patient.name}',
  );
}
