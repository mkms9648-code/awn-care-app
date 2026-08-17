import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/patient_summary.dart';
import '../theme/app_theme.dart';

const _metricLabels = {
  'hr': 'Heart Rate',
  'temp': 'Temperature',
  'spo2': 'SpO2',
  'rbs': 'RBS',
  'gcs': 'GCS',
};

class _Row {
  _Row(this.label, this.value, this.time, this.doctor, this.readings);
  final String label;
  final String value;
  final DateTime time;
  final String? doctor;
  // القراءة (أو القراءتين لو ضغط) اللي بنت الصف ده — لازمة عشان زرار
  // التعديل يعرف يبني الـ payload الكامل الجديد لنفس الحدث (event_id واحد
  // مشترك بينهم لو كانوا مسجّلين مع بعض).
  final List<VitalHistoryReading> readings;
}

/// فيتالز مقسّمة بالأيام — كل يوم قابل للطي/الفتح لوحده، وجواه جدول بسيط
/// واضح (القراءة، الوقت، الدكتور). Day 1 = يوم دخول المريض.
class VitalsHistoryView extends StatefulWidget {
  const VitalsHistoryView({super.key, required this.readings, this.encounterOpenedAt, this.onEdit});

  final List<VitalHistoryReading> readings;
  final DateTime? encounterOpenedAt;
  /// بيتنادى بزرار التعديل — الأبوين (patient_detail_screen) هو اللي بيفتح
  /// الفورم ويعمل الـ correctEvent، عشان محتاج context/provider مش متاحين هنا.
  final void Function(List<VitalHistoryReading> readings)? onEdit;

  @override
  State<VitalsHistoryView> createState() => _VitalsHistoryViewState();
}

class _VitalsHistoryViewState extends State<VitalsHistoryView> {
  final Set<DateTime> _expandedDays = {};
  static final _timeFmt = DateFormat('dd-MM-yyyy hh:mm a');

  List<_Row> _rowsFor(List<VitalHistoryReading> dayReadings) {
    final byTime = <DateTime, List<VitalHistoryReading>>{};
    for (final r in dayReadings) {
      byTime.putIfAbsent(r.measuredAt, () => []).add(r);
    }
    final rows = <_Row>[];
    for (final entry in byTime.entries) {
      final time = entry.key;
      final batch = entry.value;
      VitalHistoryReading? sys, dia;
      for (final r in batch) {
        if (r.metric == 'bp_sys') sys = r;
        if (r.metric == 'bp_dia') dia = r;
      }
      if (sys != null || dia != null) {
        rows.add(_Row(
          'BP',
          '${sys?.value.round() ?? '—'}/${dia?.value.round() ?? '—'}',
          time,
          sys?.recordedBy ?? dia?.recordedBy,
          [if (sys != null) sys, if (dia != null) dia],
        ));
      }
      for (final r in batch) {
        if (r.metric == 'bp_sys' || r.metric == 'bp_dia') continue;
        final label = _metricLabels[r.metric] ?? r.metric;
        final unit = r.unit != null && r.unit!.isNotEmpty ? ' ${r.unit}' : '';
        rows.add(_Row(label, '${r.value}$unit', time, r.recordedBy, [r]));
      }
    }
    rows.sort((a, b) => a.time.compareTo(b.time));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.readings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text('No readings yet', style: TextStyle(color: Colors.grey, fontSize: 13)),
      );
    }

    final byDay = <DateTime, List<VitalHistoryReading>>{};
    for (final r in widget.readings) {
      final day = DateTime(r.measuredAt.year, r.measuredAt.month, r.measuredAt.day);
      byDay.putIfAbsent(day, () => []).add(r);
    }
    final days = byDay.keys.toList()..sort();
    if (_expandedDays.isEmpty) _expandedDays.add(days.last);

    final base = widget.encounterOpenedAt != null
        ? DateTime(widget.encounterOpenedAt!.year, widget.encounterOpenedAt!.month, widget.encounterOpenedAt!.day)
        : days.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final day in days) ...[
          _dayHeader(theme, day, day.difference(base).inDays + 1, byDay[day]!.length),
          if (_expandedDays.contains(day)) _dayTable(theme, _rowsFor(byDay[day]!)),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _dayHeader(ThemeData theme, DateTime day, int dayNumber, int count) {
    final expanded = _expandedDays.contains(day);
    return InkWell(
      onTap: () => setState(() {
        if (expanded) {
          _expandedDays.remove(day);
        } else {
          _expandedDays.add(day);
        }
      }),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            AnimatedRotation(
              turns: expanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 150),
              child: Icon(Icons.chevron_right, size: 20, color: theme.hintColor),
            ),
            const SizedBox(width: 4),
            Text(
              'Day $dayNumber',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
            ),
            const SizedBox(width: 6),
            Text('($count)', style: TextStyle(fontSize: 12, color: theme.hintColor)),
          ],
        ),
      ),
    );
  }

  Widget _dayTable(ThemeData theme, List<_Row> rows) {
    final headerStyle = theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: theme.hintColor);
    return Container(
      margin: const EdgeInsets.only(left: 24, bottom: 4),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.hintColor.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Reading', style: headerStyle)),
                Expanded(flex: 4, child: Text('Time', style: headerStyle)),
                Expanded(flex: 3, child: Text('By', style: headerStyle)),
                if (widget.onEdit != null) const SizedBox(width: 28),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: i.isOdd ? theme.hintColor.withValues(alpha: 0.03) : null,
                border: i < rows.length - 1 ? Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5))) : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text('${rows[i].label} ${rows[i].value}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(_timeFmt.format(rows[i].time), style: const TextStyle(fontSize: 11.5)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      rows[i].doctor != null ? 'Dr. ${rows[i].doctor}' : '—',
                      style: TextStyle(fontSize: 11.5, color: theme.hintColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.onEdit != null)
                    SizedBox(
                      width: 28,
                      child: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        tooltip: 'Edit',
                        onPressed: () => widget.onEdit!(rows[i].readings),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
