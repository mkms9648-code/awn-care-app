import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/patient_summary.dart';
import 'medical_ar_translate.dart';
import 'ticket_utils.dart';

/// روشتة (Rx) منفصلة عن التقرير العام — تصميم مخصص لصفحة دوا فعلية بدل
/// سطور نص عادية: هيدر لوجو مركزي صغير، بيانات مريض في بوكس، تحذير حساسية
/// بارز لو موجود، وقائمة أدوية مرقّمة بخط واضح.
///
/// [PrescriptionLanguage.arabic]: العناوين الثابتة والجرعة/طريقة الاستخدام
/// بتتحول عربي (قاموس مصطلحات معروف، مش ترجمة آلية حرة — آمن). **اسم الدواء
/// نفسه يفضل انجليزي دايمًا** (نفس الاسم على العلبة، تجنبًا لأي لبس في
/// الصيدلية). التعليمات (Instructions) بتتعرض زي ما هي من غير أي ترجمة —
/// لو الطبيب كتبها عربي أصلًا (مسموح، مفيش قيد على لغة الحقل ده) هتظهر عربي
/// صح؛ ترجمة نص حر بقاموس مش آمنة لحاجة طبية فبنتجنبها عمدًا.
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

class _Strings {
  const _Strings({
    required this.prescription,
    required this.patient,
    required this.mrn,
    required this.ticket,
    required this.ageSex,
    required this.unit,
    required this.attending,
    required this.male,
    required this.female,
    required this.allergies,
    required this.instructions,
    required this.signature,
    required this.footer,
  });

  final String prescription;
  final String patient;
  final String mrn;
  final String ticket;
  final String ageSex;
  final String unit;
  final String attending;
  final String male;
  final String female;
  final String allergies;
  final String instructions;
  final String signature;
  final String Function(String dateTime) footer;

  static const en = _Strings(
    prescription: 'Prescription',
    patient: 'Patient',
    mrn: 'MRN',
    ticket: 'Ticket',
    ageSex: 'Age / Sex',
    unit: 'Unit',
    attending: 'Attending',
    male: 'Male',
    female: 'Female',
    allergies: 'ALLERGIES',
    instructions: 'Instructions',
    signature: 'Physician signature',
    footer: _footerEn,
  );

  static const ar = _Strings(
    prescription: 'روشتة',
    patient: 'المريض',
    mrn: 'رقم الملف',
    ticket: 'تذكرة',
    ageSex: 'السن / النوع',
    unit: 'القسم',
    attending: 'الطبيب المعالج',
    male: 'ذكر',
    female: 'أنثى',
    allergies: 'حساسية',
    instructions: 'تعليمات',
    signature: 'توقيع الطبيب',
    footer: _footerAr,
  );

  static String _footerEn(String dt) =>
      'Generated via Awn Care on $dt — reflects the physician\'s documented active medications.';
  static String _footerAr(String dt) => 'تم الإصدار عن طريق Awn Care بتاريخ $dt — طبقًا للأدوية النشطة المسجّلة.';
}

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

pw.Widget _infoRow(String label, String value, bool rtl) {
  final labelWidget = pw.SizedBox(
    width: 62,
    child: pw.Text(label, style: pw.TextStyle(font: _regular, fontSize: 8.5, color: PdfColors.grey600)),
  );
  final valueWidget = pw.Expanded(
    child: pw.Text(value, style: pw.TextStyle(font: _bold, fontSize: 10, color: _brandBlueDeep)),
  );
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: rtl ? [valueWidget, pw.SizedBox(width: 8), labelWidget] : [labelWidget, valueWidget],
    ),
  );
}

/// بيبني PDF روشتة لقائمة أدوية فعالة — مفيش استدعاء ليها لو القائمة فاضية،
/// الكارتر (patient_detail_screen) بيتأكد من كده الأول. [instructions]
/// اختياري — تعليمات المريض (kind='health_education') بتتحط تحت الأدوية لو
/// موجودة، عشان تبقى جزء من نفس الورقة اللي المريض هياخدها معاه.
Future<Uint8List> buildPrescriptionPdf(
  PatientSummary summary, {
  List<NoteHistoryEntry> instructions = const [],
  PrescriptionLanguage language = PrescriptionLanguage.english,
}) async {
  await _ensureAssets();
  final doc = pw.Document();
  final theme = pw.ThemeData.withFont(base: _regular!, bold: _bold!);
  final ar = language == PrescriptionLanguage.arabic;
  final t = ar ? _Strings.ar : _Strings.en;
  final textDirection = ar ? pw.TextDirection.rtl : pw.TextDirection.ltr;
  final crossStart = ar ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start;

  final p = summary.patient;
  final e = summary.encounter;
  final meds = summary.activeMedications;
  final ticket = e.handle != null ? cleanTicket(e.handle!) : null;
  final ageLine = p.birthYear != null ? '${DateTime.now().year - p.birthYear!} yrs' : '—';
  final sexLine = p.sex == 'm' ? t.male : (p.sex == 'f' ? t.female : '—');
  final now = DateTime.now();

  doc.addPage(
    pw.MultiPage(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(34, 30, 34, 26),
      textDirection: textDirection,
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
                  t.prescription,
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

          // ===== Patient info box =====
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
                    crossAxisAlignment: crossStart,
                    children: [
                      _infoRow(t.patient, p.name, ar),
                      _infoRow(t.mrn, p.mrn, ar),
                      if (ticket != null) _infoRow(t.ticket, '#$ticket', ar),
                    ],
                  ),
                ),
                pw.SizedBox(width: 18),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: crossStart,
                    children: [
                      _infoRow(t.ageSex, '$ageLine · $sexLine', ar),
                      if (e.unit != null) _infoRow(t.unit, e.unit!, ar),
                      if (e.attending != null) _infoRow(t.attending, 'Dr. ${e.attending}', ar),
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
                '${t.allergies}: ${p.allergies.join(', ')}',
                style: pw.TextStyle(font: _bold, fontSize: 9.5, color: PdfColors.red900),
              ),
            ),
          ],

          pw.SizedBox(height: 22),

          // ===== Rx list =====
          // اسم الدواء نفسه يفضل انجليزي دايمًا (عمدًا، حتى في النسخة
          // العربية) — الجرعة/الطريقة/التكرار بس هما اللي بيتترجموا لو عربي.
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
                        pw.Directionality(
                          textDirection: pw.TextDirection.ltr,
                          child: pw.Text(
                            meds[i].name,
                            style: pw.TextStyle(font: _bold, fontSize: 12.5, color: _brandBlueDeep),
                          ),
                        ),
                        if ([meds[i].dose, meds[i].route, meds[i].frequency]
                            .whereType<String>()
                            .where((s) => s.isNotEmpty)
                            .isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            [
                              if (meds[i].dose != null && meds[i].dose!.isNotEmpty)
                                ar ? translateDose(meds[i].dose!) : meds[i].dose!,
                              if (meds[i].route != null && meds[i].route!.isNotEmpty)
                                ar ? translateRoute(meds[i].route!) : meds[i].route!,
                              if (meds[i].frequency != null && meds[i].frequency!.isNotEmpty)
                                ar ? translateFrequency(meds[i].frequency!) : meds[i].frequency!,
                            ].join('  ·  '),
                            style: pw.TextStyle(font: _regular, fontSize: 10, color: PdfColors.grey700),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ===== Patient instructions =====
          // النص زي ما هو من غير أي ترجمة — لو الطبيب كتبه عربي أصلًا هيظهر
          // صح، وترجمة نص حر بقاموس مش آمنة لحاجة طبية.
          if (instructions.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              t.instructions,
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
                  for (final note in instructions)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('•  ', style: pw.TextStyle(font: _bold, fontSize: 10, color: _brandBlue)),
                          pw.Expanded(
                            child: pw.Text(note.body, style: pw.TextStyle(font: _regular, fontSize: 10)),
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
                    e.attending != null ? 'Dr. ${e.attending}' : t.signature,
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
            t.footer(_dateTimeFmt.format(now)),
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
}) async {
  final bytes = await buildPrescriptionPdf(summary, instructions: instructions, language: language);
  final dir = await getTemporaryDirectory();
  final safeName = summary.patient.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');
  final file = File('${dir.path}/awn-care-rx-$safeName.pdf');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles(
    [XFile(file.path)],
    subject: 'Prescription — ${summary.patient.name}',
  );
}
