import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/analytics_summary.dart';
import '../models/calendar_followup.dart';
import '../providers/calendar_provider.dart';
import '../theme/app_theme.dart';
import 'patient_detail_screen.dart';

const _weekdayLabels = ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
final _monthFmt = DateFormat('MMMM yyyy');
final _timeFmt = DateFormat('h:mm a');

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

enum _CalendarView { calendar, trends }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  _CalendarView _view = _CalendarView.calendar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Follow-up Calendar'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SegmentedButton<_CalendarView>(
              segments: const [
                ButtonSegment(value: _CalendarView.calendar, label: Text('Calendar'), icon: Icon(Icons.calendar_month_outlined, size: 17)),
                ButtonSegment(value: _CalendarView.trends, label: Text('Trends'), icon: Icon(Icons.bar_chart_outlined, size: 17)),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() => _view = s.first),
            ),
          ),
        ),
      ),
      body: Consumer<CalendarProvider>(
        builder: (context, provider, _) {
          return _view == _CalendarView.calendar ? _CalendarBody(provider: provider) : _TrendsBody(provider: provider);
        },
      ),
    );
  }
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody({required this.provider});
  final CalendarProvider provider;

  @override
  Widget build(BuildContext context) {
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

// ============================================================================
// Trends — drill-down: months → weeks in a month → weekdays in a week.
// ============================================================================

class _TrendsBody extends StatelessWidget {
  const _TrendsBody({required this.provider});
  final CalendarProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.trendsLoading) return const Center(child: CircularProgressIndicator());
    if (provider.trendsError != null) return Center(child: Text(provider.trendsError!));

    final List<LabeledCount> bars;
    final List<dynamic> keys;
    if (provider.isMonthLevel) {
      bars = provider.monthBars;
      keys = provider.monthBarKeys;
    } else if (provider.isWeekLevel) {
      bars = provider.weekBars;
      keys = provider.weekBarKeys;
    } else {
      bars = provider.weekdayBars;
      keys = const [];
    }

    return RefreshIndicator(
      onRefresh: provider.loadTrends,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              if (!provider.isMonthLevel)
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: provider.drillUp,
                ),
              Expanded(
                child: Text(
                  provider.trendBreadcrumb,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            provider.isMonthLevel
                ? 'Follow-ups by month — tap a bar to see its weeks'
                : provider.isWeekLevel
                    ? 'Follow-ups by week — tap a bar to see its days'
                    : 'Follow-ups by day of the week',
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 16),
          if (bars.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('No follow-ups in this range', style: TextStyle(color: Theme.of(context).hintColor)),
              ),
            )
          else
            _TrendsChart(
              data: bars,
              onBarTap: provider.isWeekdayLevel
                  ? null
                  : (index) {
                      if (provider.isMonthLevel) {
                        provider.drillIntoMonth(keys[index] as DateTime);
                      } else if (provider.isWeekLevel) {
                        provider.drillIntoWeek(keys[index] as int);
                      }
                    },
            ),
        ],
      ),
    );
  }
}

/// نفس ريسبي _WeekdayChart بالظبط بتاع تاب Analytics — لون واحد ومقياس
/// تدرّجي (مش هويّات مختلفة)، عشان الشكل يبقى متسق مع باقي التطبيق.
class _TrendsChart extends StatelessWidget {
  const _TrendsChart({required this.data, required this.onBarTap});
  final List<LabeledCount> data;
  final void Function(int index)? onBarTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxCount = data.map((d) => d.count).fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = maxCount == 0 ? 4.0 : maxCount + (maxCount * 0.25).clamp(1, 999);

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY.toDouble(),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(data[i].label, style: TextStyle(fontSize: 10.5, color: theme.hintColor)),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${rod.toY.toInt()}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            touchCallback: onBarTap == null
                ? null
                : (event, response) {
                    if (event is! FlTapUpEvent) return;
                    final index = response?.spot?.touchedBarGroupIndex;
                    if (index != null && index >= 0 && index < data.length) onBarTap!(index);
                  },
          ),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i].count.toDouble(),
                    color: AppTheme.primaryBlue,
                    width: 18,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
