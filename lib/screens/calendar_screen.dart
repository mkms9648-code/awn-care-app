import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/calendar_followup.dart';
import '../providers/calendar_provider.dart';
import '../theme/app_theme.dart';
import 'patient_detail_screen.dart';

const _weekdayLabels = ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
final _monthFmt = DateFormat('MMMM yyyy');
final _timeFmt = DateFormat('h:mm a');

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Follow-up Calendar')),
      body: Consumer<CalendarProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: provider.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _MonthHeader(provider: provider),
                if (provider.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (provider.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text(provider.error!)),
                  )
                else
                  _MonthGrid(provider: provider),
                const Divider(height: 1),
                _DayList(provider: provider),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.provider});
  final CalendarProvider provider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: provider.prevMonth),
          Text(_monthFmt.format(provider.focusedMonth), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: provider.nextMonth),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.provider});
  final CalendarProvider provider;

  @override
  Widget build(BuildContext context) {
    final byDay = provider.byDay;
    final today = DateTime.now();
    final days = <DateTime>[];
    for (var d = provider.gridStart; !d.isAfter(provider.gridEnd); d = d.add(const Duration(days: 1))) {
      days.add(d);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Row(
            children: [
              for (final label in _weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).hintColor)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.05,
            children: [
              for (final day in days)
                _DayCell(
                  day: day,
                  inMonth: day.month == provider.focusedMonth.month,
                  isToday: _isSameDay(day, today),
                  isSelected: _isSameDay(day, provider.selectedDay),
                  items: byDay[DateTime(day.year, day.month, day.day)] ?? const [],
                  onTap: () => provider.selectDay(day),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.items,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final List<CalendarFollowUp> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasOverdue = items.any((i) => i.isOverdue);
    final dotColor = items.isEmpty ? null : (hasOverdue ? AppTheme.criticalRed : AppTheme.primaryBlue);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isToday && !isSelected ? Border.all(color: AppTheme.primaryBlue, width: 1.4) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? Colors.white
                    : inMonth
                        ? null
                        : Theme.of(context).hintColor.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 6,
              child: dotColor == null
                  ? null
                  : Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? Colors.white : dotColor,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayList extends StatelessWidget {
  const _DayList({required this.provider});
  final CalendarProvider provider;

  @override
  Widget build(BuildContext context) {
    final items = provider.selectedDayItems;
    final dateLabel = DateFormat('EEEE, MMM d').format(provider.selectedDay);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No follow-ups this day', style: TextStyle(color: Theme.of(context).hintColor)),
              ),
            )
          else
            for (final item in items) _FollowUpTile(item: item),
        ],
      ),
    );
  }
}

class _FollowUpTile extends StatelessWidget {
  const _FollowUpTile({required this.item});
  final CalendarFollowUp item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          item.isOverdue ? Icons.schedule : Icons.event_available_outlined,
          color: item.isOverdue ? AppTheme.criticalRed : AppTheme.primaryBlue,
        ),
        title: Text(item.patientName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [item.text, if (item.handle != null) item.handle!, _timeFmt.format(item.dueAt)].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PatientDetailScreen(encounterId: item.encounterId, botKey: 'clinic'),
          ),
        ),
      ),
    );
  }
}
