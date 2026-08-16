import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/patient_summary.dart';
import '../theme/app_theme.dart';

final _dateTimeFmt = DateFormat('dd-MM-yyyy, hh:mm a');

/// قائمة ملاحظات مؤرّخة — تُستخدم لـ Treatment Plan/التنبيهات وتعليمات
/// العلاج/نتائج التحاليل. النص بيتعرض زي ما هو من غير تقصير.
class NoteHistoryListView extends StatelessWidget {
  const NoteHistoryListView({super.key, required this.notes, required this.emptyHint});

  final List<NoteHistoryEntry> notes;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(emptyHint, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      );
    }
    final ordered = notes.reversed.toList(); // الأحدث فوق
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final n in ordered)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.body, style: const TextStyle(fontSize: 13.5, height: 1.5)),
                const SizedBox(height: 4),
                Text(
                  '${n.authoredBy != null ? 'Dr. ${n.authoredBy}' : 'Unknown'} · ${_dateTimeFmt.format(n.authoredAt)}',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// روشتة كاملة — أدوية نشطة ومتوقفة، بترتيب زمني (الأحدث فوق)، مع شارة حالة.
class MedicationHistoryListView extends StatelessWidget {
  const MedicationHistoryListView({super.key, required this.medications});

  final List<MedicationHistoryEntry> medications;

  static final _dateFmt = DateFormat('dd-MM-yyyy');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (medications.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text('No prescriptions yet', style: TextStyle(color: Colors.grey, fontSize: 13)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final m in medications)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (m.isActive ? AppTheme.successGreen : theme.hintColor).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        m.isActive ? 'Active' : 'Stopped',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: m.isActive ? AppTheme.successGreen : theme.hintColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if ([m.dose, m.route, m.frequency].whereType<String>().where((s) => s.isNotEmpty).isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    [m.dose, m.route, m.frequency].whereType<String>().where((s) => s.isNotEmpty).join('  ·  '),
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  [
                    if (m.startsAt != null) 'Started ${_dateFmt.format(m.startsAt!)}',
                    if (m.endsAt != null) 'Stopped ${_dateFmt.format(m.endsAt!)}',
                    if (m.prescribedBy != null) 'Dr. ${m.prescribedBy}',
                  ].join(' · '),
                  style: TextStyle(fontSize: 11, color: theme.hintColor),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
