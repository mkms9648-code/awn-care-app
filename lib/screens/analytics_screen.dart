import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/analytics_summary.dart';
import '../providers/analytics_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/calendar_provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'calendar_screen.dart';

// ترتيب ثابت للألوان التصنيفية (هوية: قسم/تشخيص/دكتور...) — نفس الترتيب
// دايمًا، ومايتلمسش لو عدد العناصر اتغيّر (كل عنصر ليه لون ثابت بالترتيب).
const _chartPalette = [
  AppTheme.primaryBlue,
  AppTheme.accentOrange,
  AppTheme.successGreen,
  AppTheme.criticalRed,
  AppTheme.primaryBlueLight,
  Colors.teal,
  Colors.purple,
  Colors.brown,
];

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnalyticsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          if (provider.hasClinic)
            IconButton(
              icon: const Icon(Icons.calendar_month_outlined),
              tooltip: 'Follow-up calendar',
              onPressed: () => _openCalendar(context),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: provider.load, tooltip: 'Refresh'),
        ],
        bottom: provider.hasHospital && provider.hasClinic
            ? PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SegmentedButton<AnalyticsScope>(
                    segments: const [
                      ButtonSegment(value: AnalyticsScope.hospital, label: Text('Hospital')),
                      ButtonSegment(value: AnalyticsScope.clinic, label: Text('Clinic')),
                    ],
                    selected: {provider.scope},
                    onSelectionChanged: (s) => provider.setScope(s.first),
                  ),
                ),
              )
            : null,
      ),
      body: _buildBody(context, provider),
    );
  }

  void _openCalendar(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final supabase = context.read<SupabaseService>();
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<CalendarProvider>(
          create: (_) => CalendarProvider(supabaseService: supabase, entryCode: auth.entryCode!),
          child: const CalendarScreen(),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AnalyticsProvider provider) {
    if (provider.isLoading && provider.summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.summary == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(provider.error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: provider.load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final summary = provider.summary ?? AnalyticsSummary.empty;
    final isWorkspace = provider.level == AnalyticsLevel.workspace;

    if (!summary.hasAnyData && provider.level == AnalyticsLevel.mine) {
      return RefreshIndicator(
        onRefresh: provider.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 12),
            _LevelToggle(provider: provider),
            const SizedBox(height: 78),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.analytics_outlined, size: 44, color: AppTheme.primaryBlue),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No data yet',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your workload and case analytics will appear here once you start treating patients.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _LevelToggle(provider: provider),
          const SizedBox(height: 16),
          _StatGrid(summary: summary, isWorkspace: isWorkspace),
          if (isWorkspace && summary.doctorWorkload.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Team Workload',
              subtitle: 'Active cases per doctor right now',
              child: _DoctorWorkloadChart(data: summary.doctorWorkload),
            ),
          ],
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Workload — Last 14 Days',
            child: _WorkloadChart(data: summary.casesPerDay),
          ),
          if (summary.weekdayWorkload.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Busiest Days',
              subtitle: 'New cases by day of week — last 90 days',
              child: _WeekdayChart(data: summary.weekdayWorkload),
            ),
          ],
          if (summary.unitDistribution.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Cases by Department',
              child: _PieChartWithLegend(data: summary.unitDistribution),
            ),
          ],
          if (summary.sourceMix.length > 1) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Case Source',
              child: _PieChartWithLegend(data: summary.sourceMix, capitalizeLabels: true),
            ),
          ],
          if (summary.topConditions.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Most Common Diagnoses',
              child: _HorizontalBarList(data: summary.topConditions),
            ),
          ],
          if (summary.ordersByCategory.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Orders by Category',
              child: _HorizontalBarList(data: summary.ordersByCategory, capitalizeLabels: true),
            ),
          ],
          if (summary.ordersTurnaround.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Order Turnaround Time',
              subtitle: 'Average time from order to result, last period',
              child: _TurnaroundList(data: summary.ordersTurnaround),
            ),
          ],
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Commitments',
            child: _MiniStatRow(
              stats: [
                _MiniStat('Open', '${summary.commitmentsOpen}', AppTheme.primaryBlue),
                _MiniStat('Overdue', '${summary.commitmentsOverdue}',
                    summary.commitmentsOverdue > 0 ? AppTheme.criticalRed : AppTheme.successGreen),
                _MiniStat('Done (30d)', '${summary.commitmentsDonePeriod}', AppTheme.successGreen),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Complications',
            child: _MiniStatRow(
              stats: [
                _MiniStat('Open', '${summary.complicationsOpen}',
                    summary.complicationsOpen > 0 ? AppTheme.accentOrange : AppTheme.successGreen),
                _MiniStat('Resolved (30d)', '${summary.complicationsResolvedPeriod}', AppTheme.successGreen),
                _MiniStat(
                  'Avg Resolution',
                  summary.avgComplicationResolutionHours != null
                      ? '${summary.avgComplicationResolutionHours!.toStringAsFixed(1)}h'
                      : '—',
                  AppTheme.primaryBlue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelToggle extends StatelessWidget {
  const _LevelToggle({required this.provider});
  final AnalyticsProvider provider;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AnalyticsLevel>(
      segments: const [
        ButtonSegment(value: AnalyticsLevel.mine, label: Text('Me'), icon: Icon(Icons.person_outline, size: 17)),
        ButtonSegment(
            value: AnalyticsLevel.workspace, label: Text('Team'), icon: Icon(Icons.groups_outlined, size: 17)),
      ],
      selected: {provider.level},
      onSelectionChanged: (s) => provider.setLevel(s.first),
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.summary, required this.isWorkspace});
  final AnalyticsSummary summary;
  final bool isWorkspace;

  @override
  Widget build(BuildContext context) {
    final stats = <_Stat>[
      _Stat('Total Cases', '${summary.totalCases}', Icons.folder_outlined, AppTheme.primaryBlue),
      _Stat('Active Now', '${summary.activeCases}', Icons.bolt_outlined, AppTheme.accentOrange),
      _Stat('Today', '${summary.casesToday}', Icons.today_outlined, AppTheme.primaryBlueLight),
      _Stat('New (30d)', '${summary.newCasesPeriod}', Icons.trending_up, AppTheme.successGreen),
      _Stat('Discharged (30d)', '${summary.dischargedPeriod}', Icons.logout, AppTheme.primaryBlueLight),
      if (summary.avgLosDays != null)
        _Stat('Avg. Stay', '${summary.avgLosDays!.toStringAsFixed(1)}d', Icons.timelapse, AppTheme.criticalRed),
      _Stat(
        'Overdue Orders',
        '${summary.ordersOverdueCount}',
        Icons.warning_amber_outlined,
        summary.ordersOverdueCount > 0 ? AppTheme.criticalRed : AppTheme.successGreen,
      ),
      if (isWorkspace)
        _Stat('Active Doctors', '${summary.activeDoctorsCount}', Icons.groups_outlined, AppTheme.primaryBlue),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final s in stats) SizedBox(width: cardWidth, child: _StatCardWidget(stat: s)),
          ],
        );
      },
    );
  }
}

class _StatCardWidget extends StatelessWidget {
  const _StatCardWidget({required this.stat});
  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(stat.icon, size: 18, color: stat.color),
          ),
          const SizedBox(height: 10),
          Text(stat.value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(stat.label, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
          ],
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _MiniStat {
  const _MiniStat(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;
}

class _MiniStatRow extends StatelessWidget {
  const _MiniStatRow({required this.stats});
  final List<_MiniStat> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (final s in stats)
          Expanded(
            child: Column(
              children: [
                Text(s.value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: s.color)),
                const SizedBox(height: 4),
                Text(s.label, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor), textAlign: TextAlign.center),
              ],
            ),
          ),
      ],
    );
  }
}

class _WorkloadChart extends StatelessWidget {
  const _WorkloadChart({required this.data});
  final List<DailyCount> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) return const SizedBox(height: 160);

    final maxCount = data.map((d) => d.count).fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = maxCount == 0 ? 4.0 : maxCount + (maxCount * 0.25).clamp(1, 999);

    return SizedBox(
      height: 180,
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
                  // بنعرض تسمية كل يومين بس عشان محدش يتزاحم على شاشة الموبايل.
                  if (i % 2 != 0 && i != data.length - 1) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      DateFormat('d/M').format(data[i].date),
                      style: TextStyle(fontSize: 9, color: theme.hintColor),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i].count.toDouble(),
                    color: AppTheme.primaryBlue,
                    width: 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${rod.toY.toInt()}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// نمط الحمل حسب يوم الأسبوع — قيمة واحدة (عدد الحالات) لكل يوم، فبنستخدم
/// درجة واحدة من نفس اللون (مقياس تدرّجي) مش ألوان مختلفة، لأنها مش هويّات
/// منفصلة زي الأقسام — هي نفس المقياس بترتيب اليوم.
class _WeekdayChart extends StatelessWidget {
  const _WeekdayChart({required this.data});
  final List<LabeledCount> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxCount = data.map((d) => d.count).fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = maxCount == 0 ? 4.0 : maxCount + (maxCount * 0.25).clamp(1, 999);

    return SizedBox(
      height: 160,
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
                reservedSize: 22,
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
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i].count.toDouble(),
                    // اليوم اللي فيه أكتر حمل بيتلوّن بارز، الباقي بلون أهدأ من
                    // نفس الدرجة — إبراز الأعلى من غير استخدام ألوان تصنيفية.
                    color: data[i].count == maxCount && maxCount > 0
                        ? AppTheme.primaryBlue
                        : AppTheme.primaryBlue.withValues(alpha: 0.35),
                    width: 20,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${rod.toY.toInt()}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// حمل كل دكتور — هويات منفصلة (كل دكتور له لون ثابت بالترتيب)، شريط أفقي
/// عشان الأسماء ممكن تطول وعدد الدكاترة متغيّر.
class _DoctorWorkloadChart extends StatelessWidget {
  const _DoctorWorkloadChart({required this.data});
  final List<DoctorWorkload> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxCount = data.map((d) => d.activeCases).fold<int>(0, (a, b) => a > b ? a : b);

    return Column(
      children: [
        for (var i = 0; i < data.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == data.length - 1 ? 0 : 12),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _chartPalette[i % _chartPalette.length],
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: Text(
                    data[i].name,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final ratio = maxCount == 0 ? 0.0 : data[i].activeCases / maxCount;
                        return Stack(
                          children: [
                            Container(height: 10, width: constraints.maxWidth, color: theme.dividerColor.withValues(alpha: 0.1)),
                            Container(
                              height: 10,
                              width: constraints.maxWidth * ratio.clamp(0.03, 1.0),
                              decoration: BoxDecoration(
                                color: _chartPalette[i % _chartPalette.length],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 24,
                  child: Text(
                    '${data[i].activeCases}',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PieChartWithLegend extends StatelessWidget {
  const _PieChartWithLegend({required this.data, this.capitalizeLabels = false});
  final List<LabeledCount> data;
  final bool capitalizeLabels;

  String _display(String label) {
    if (!capitalizeLabels || label.isEmpty) return label;
    return label[0].toUpperCase() + label.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = data.fold<int>(0, (a, b) => a + b.count);

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                for (var i = 0; i < data.length; i++)
                  PieChartSectionData(
                    value: data[i].count.toDouble(),
                    color: _chartPalette[i % _chartPalette.length],
                    title: total == 0 ? '' : '${(data[i].count / total * 100).round()}%',
                    radius: 50,
                    titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            for (var i = 0; i < data.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: _chartPalette[i % _chartPalette.length], shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text('${_display(data[i].label)} (${data[i].count})', style: theme.textTheme.bodySmall),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _HorizontalBarList extends StatelessWidget {
  const _HorizontalBarList({required this.data, this.capitalizeLabels = false});
  final List<LabeledCount> data;
  final bool capitalizeLabels;

  String _display(String label) {
    if (!capitalizeLabels || label.isEmpty) return label;
    return label[0].toUpperCase() + label.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxCount = data.map((d) => d.count).fold<int>(0, (a, b) => a > b ? a : b);

    return Column(
      children: [
        for (var i = 0; i < data.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == data.length - 1 ? 0 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _display(data[i].label),
                        style: theme.textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${data[i].count}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final ratio = maxCount == 0 ? 0.0 : data[i].count / maxCount;
                      return Stack(
                        children: [
                          Container(height: 8, width: constraints.maxWidth, color: theme.dividerColor.withValues(alpha: 0.1)),
                          Container(
                            height: 8,
                            width: constraints.maxWidth * ratio.clamp(0.03, 1.0),
                            decoration: BoxDecoration(
                              color: _chartPalette[i % _chartPalette.length],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// سرعة تنفيذ الطلبات — مش هوية، ده أداء/التزام بوقت، فالألوان هنا "حالة"
/// (أخضر سريع / برتقالي متوسط / أحمر بطيء) بدل الألوان التصنيفية — نفس منطق
/// إشارات SLA في لوحات التشغيل.
class _TurnaroundList extends StatelessWidget {
  const _TurnaroundList({required this.data});
  final List<OrderTurnaround> data;

  Color _bandColor(double hours) {
    if (hours <= 6) return AppTheme.successGreen;
    if (hours <= 24) return AppTheme.accentOrange;
    return AppTheme.criticalRed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (var i = 0; i < data.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == data.length - 1 ? 0 : 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(color: _bandColor(data[i].avgHours), shape: BoxShape.circle),
                ),
                Expanded(
                  child: Text(
                    data[i].category[0].toUpperCase() + data[i].category.substring(1),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '${data[i].avgHours.toStringAsFixed(1)}h',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: _bandColor(data[i].avgHours)),
                ),
                const SizedBox(width: 8),
                Text('(${data[i].resolvedCount})', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
              ],
            ),
          ),
      ],
    );
  }
}
