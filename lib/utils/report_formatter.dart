import 'package:intl/intl.dart';

import '../models/encounter.dart';
import '../models/patient_summary.dart';
import '../services/supabase_service.dart';
import 'ticket_utils.dart';

final _reportDateFormat = DateFormat('dd-MM-yyyy, hh:mm a');

String _fmt(DateTime? d) => d == null ? '—' : _reportDateFormat.format(d);

/// تقرير تيكست منظّم لمريض واحد — جاهز للإرسال على واتساب أو أي تطبيق.
String formatPatientReport(PatientSummary s) {
  final p = s.patient;
  final e = s.encounter;
  final b = StringBuffer();

  b.writeln('👤 ${p.name}');
  final ageLine = p.birthYear != null ? '${DateTime.now().year - p.birthYear!} yrs' : null;
  b.writeln(
    'MRN: ${p.mrn}'
    '${ageLine != null ? ' | $ageLine' : ''}'
    '${p.sex != null ? ' | ${p.sex == 'm' ? 'Male' : 'Female'}' : ''}',
  );
  if (e.handle != null) b.writeln('Ticket: #${cleanTicket(e.handle!)}');
  b.writeln(
    'Status: ${e.status == 'active' ? 'Active' : 'Discharged'}'
    '${e.status == 'active' ? '' : ' (${_fmt(e.dischargedAt)})'}',
  );
  if (e.unit != null) b.writeln('Unit: ${e.unit}');
  if (e.attending != null) b.writeln('Attending: Dr. ${e.attending}');
  if (p.allergies.isNotEmpty) b.writeln('Allergies: ${p.allergies.join(', ')}');
  if (p.chronicConditions.isNotEmpty) b.writeln('Chronic: ${p.chronicConditions.join(', ')}');

  if (s.latestVitals.isNotEmpty) {
    b.writeln();
    b.writeln('VITALS');
    for (final v in s.latestVitals) {
      b.writeln('- ${v.metric}: ${v.value}${v.unit != null ? ' ${v.unit}' : ''} (${_fmt(v.measuredAt)})');
    }
  }

  if (s.openOrders.isNotEmpty) {
    b.writeln();
    b.writeln('ORDERS');
    for (final o in s.openOrders) {
      final mark = o.isCompleted ? '✅' : (o.isCancelled ? '❌' : '⬜');
      final status = o.isCompleted
          ? 'done ${_fmt(o.resolvedAt)}'
          : (o.isCancelled ? 'cancelled' : 'pending');
      b.writeln('$mark ${o.name} (${o.category}) — $status');
    }
  }

  if (s.activeMedications.isNotEmpty) {
    b.writeln();
    b.writeln('MEDICATIONS');
    for (final m in s.activeMedications) {
      final details = [m.dose, m.route, m.frequency].whereType<String>().where((x) => x.isNotEmpty);
      b.writeln('- ${m.name}${details.isNotEmpty ? ' (${details.join(', ')})' : ''}');
    }
  }

  if (s.recentNotes.isNotEmpty) {
    b.writeln();
    b.writeln('NOTES');
    for (final n in s.recentNotes) {
      b.writeln('[${n.kind}] ${n.body}');
    }
  }

  if (s.openComplications.isNotEmpty) {
    b.writeln();
    b.writeln('COMPLICATIONS');
    for (final c in s.openComplications) {
      b.writeln('- ${c.description}');
    }
  }

  if (s.openCommitments.isNotEmpty) {
    b.writeln();
    b.writeln('COMMITMENTS');
    for (final c in s.openCommitments) {
      b.writeln('- ${c.text}${c.dueAt != null ? ' (due ${_fmt(c.dueAt)})' : ''}${c.isOverdue ? ' [OVERDUE]' : ''}');
    }
  }

  if (s.attachments.isNotEmpty) {
    b.writeln();
    b.writeln('Attachments: ${s.attachments.length} photo(s)');
  }

  return b.toString().trimRight();
}

/// تقرير مجمّع لقائمة حالات مفلترة — بيجيب التفاصيل الكاملة لكل مريض (مش
/// سطر ملخص بس)، عشان كده بينادي patientSummary لكل حالة على حدة. القوائم
/// المفلترة (زي "Today") صغيرة عادةً فمقبول أداءً.
Future<String> formatBoardReport({
  required SupabaseService supabaseService,
  required String entryCode,
  required String botKey,
  required List<Encounter> encounters,
  required String title,
}) async {
  final b = StringBuffer();
  b.writeln('AWN CARE — $title');
  b.writeln('Generated: ${_reportDateFormat.format(DateTime.now())}');
  b.writeln('Cases: ${encounters.length}');
  b.writeln('=' * 32);

  for (final e in encounters) {
    b.writeln();
    try {
      final summary = await supabaseService.patientSummary(
        entryCode: entryCode,
        botKey: botKey,
        encounterId: e.encounterId,
      );
      b.write(formatPatientReport(summary));
    } catch (_) {
      b.write('⚠️ Could not load full detail for ${e.patientName} (MRN ${e.mrn})');
    }
    b.writeln();
    b.writeln('-' * 32);
  }

  return b.toString().trimRight();
}
