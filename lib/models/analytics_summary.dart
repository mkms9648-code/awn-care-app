/// Point on the "cases opened per day" trend chart.
class DailyCount {
  const DailyCount({required this.date, required this.count});

  final DateTime date;
  final int count;

  factory DailyCount.fromJson(Map<String, dynamic> json) {
    return DailyCount(
      date: DateTime.tryParse(json['date']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Generic (label, count) bucket used for conditions/units/order categories.
class LabeledCount {
  const LabeledCount({required this.label, required this.count});

  final String label;
  final int count;

  factory LabeledCount.fromJson(Map<String, dynamic> json, {required String labelKey}) {
    return LabeledCount(
      label: json[labelKey]?.toString() ?? '—',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Personal performance dashboard — matches [app_analytics_summary]'s shape.
class AnalyticsSummary {
  const AnalyticsSummary({
    required this.totalCases,
    required this.activeCases,
    required this.newCasesPeriod,
    required this.dischargedPeriod,
    required this.avgLosDays,
    required this.casesPerDay,
    required this.topConditions,
    required this.unitDistribution,
    required this.ordersByCategory,
  });

  final int totalCases;
  final int activeCases;
  final int newCasesPeriod;
  final int dischargedPeriod;
  final double? avgLosDays;
  final List<DailyCount> casesPerDay;
  final List<LabeledCount> topConditions;
  final List<LabeledCount> unitDistribution;
  final List<LabeledCount> ordersByCategory;

  bool get hasAnyData => totalCases > 0;

  static const empty = AnalyticsSummary(
    totalCases: 0,
    activeCases: 0,
    newCasesPeriod: 0,
    dischargedPeriod: 0,
    avgLosDays: null,
    casesPerDay: [],
    topConditions: [],
    unitDistribution: [],
    ordersByCategory: [],
  );

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummary(
      totalCases: (json['total_cases'] as num?)?.toInt() ?? 0,
      activeCases: (json['active_cases'] as num?)?.toInt() ?? 0,
      newCasesPeriod: (json['new_cases_period'] as num?)?.toInt() ?? 0,
      dischargedPeriod: (json['discharged_period'] as num?)?.toInt() ?? 0,
      avgLosDays: (json['avg_los_days'] as num?)?.toDouble(),
      casesPerDay: (json['cases_per_day'] as List<dynamic>? ?? [])
          .map((e) => DailyCount.fromJson(e as Map<String, dynamic>))
          .toList(),
      topConditions: (json['top_conditions'] as List<dynamic>? ?? [])
          .map((e) => LabeledCount.fromJson(e as Map<String, dynamic>, labelKey: 'label'))
          .toList(),
      unitDistribution: (json['unit_distribution'] as List<dynamic>? ?? [])
          .map((e) => LabeledCount.fromJson(e as Map<String, dynamic>, labelKey: 'unit'))
          .toList(),
      ordersByCategory: (json['orders_by_category'] as List<dynamic>? ?? [])
          .map((e) => LabeledCount.fromJson(e as Map<String, dynamic>, labelKey: 'category'))
          .toList(),
    );
  }
}
