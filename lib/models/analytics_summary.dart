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

/// Average resolution time for one order category — from `orders_turnaround`.
class OrderTurnaround {
  const OrderTurnaround({required this.category, required this.avgHours, required this.resolvedCount});

  final String category;
  final double avgHours;
  final int resolvedCount;

  factory OrderTurnaround.fromJson(Map<String, dynamic> json) {
    return OrderTurnaround(
      category: json['category']?.toString() ?? '—',
      avgHours: (json['avg_hours'] as num?)?.toDouble() ?? 0,
      resolvedCount: (json['resolved_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One doctor's current load — from `doctor_workload` (workspace scope only).
class DoctorWorkload {
  const DoctorWorkload({required this.name, required this.activeCases, required this.newCasesPeriod});

  final String name;
  final int activeCases;
  final int newCasesPeriod;

  factory DoctorWorkload.fromJson(Map<String, dynamic> json) {
    return DoctorWorkload(
      name: json['label']?.toString() ?? '—',
      activeCases: (json['count'] as num?)?.toInt() ?? 0,
      newCasesPeriod: (json['new_cases_period'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Performance dashboard — matches [app_analytics_summary]'s shape (v2,
/// migration 043). p_scope='mine' shows the signed-in doctor only;
/// p_scope='workspace' adds hospital-wide fields (doctorWorkload,
/// activeDoctorsCount) on top of the same shared fields.
class AnalyticsSummary {
  const AnalyticsSummary({
    required this.totalCases,
    required this.activeCases,
    required this.newCasesPeriod,
    required this.dischargedPeriod,
    required this.casesToday,
    required this.avgLosDays,
    required this.casesPerDay,
    required this.weekdayWorkload,
    required this.topConditions,
    required this.unitDistribution,
    required this.ordersByCategory,
    required this.pendingOrdersCount,
    required this.ordersOverdueCount,
    required this.ordersTurnaround,
    required this.commitmentsOpen,
    required this.commitmentsOverdue,
    required this.commitmentsDonePeriod,
    required this.complicationsOpen,
    required this.complicationsResolvedPeriod,
    required this.avgComplicationResolutionHours,
    required this.sourceMix,
    required this.doctorWorkload,
    required this.activeDoctorsCount,
  });

  final int totalCases;
  final int activeCases;
  final int newCasesPeriod;
  final int dischargedPeriod;
  final int casesToday;
  final double? avgLosDays;
  final List<DailyCount> casesPerDay;
  final List<LabeledCount> weekdayWorkload;
  final List<LabeledCount> topConditions;
  final List<LabeledCount> unitDistribution;
  final List<LabeledCount> ordersByCategory;
  final int pendingOrdersCount;
  final int ordersOverdueCount;
  final List<OrderTurnaround> ordersTurnaround;
  final int commitmentsOpen;
  final int commitmentsOverdue;
  final int commitmentsDonePeriod;
  final int complicationsOpen;
  final int complicationsResolvedPeriod;
  final double? avgComplicationResolutionHours;
  final List<LabeledCount> sourceMix;
  final List<DoctorWorkload> doctorWorkload;
  final int activeDoctorsCount;

  bool get hasAnyData => totalCases > 0;

  static const empty = AnalyticsSummary(
    totalCases: 0,
    activeCases: 0,
    newCasesPeriod: 0,
    dischargedPeriod: 0,
    casesToday: 0,
    avgLosDays: null,
    casesPerDay: [],
    weekdayWorkload: [],
    topConditions: [],
    unitDistribution: [],
    ordersByCategory: [],
    pendingOrdersCount: 0,
    ordersOverdueCount: 0,
    ordersTurnaround: [],
    commitmentsOpen: 0,
    commitmentsOverdue: 0,
    commitmentsDonePeriod: 0,
    complicationsOpen: 0,
    complicationsResolvedPeriod: 0,
    avgComplicationResolutionHours: null,
    sourceMix: [],
    doctorWorkload: [],
    activeDoctorsCount: 0,
  );

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummary(
      totalCases: (json['total_cases'] as num?)?.toInt() ?? 0,
      activeCases: (json['active_cases'] as num?)?.toInt() ?? 0,
      newCasesPeriod: (json['new_cases_period'] as num?)?.toInt() ?? 0,
      dischargedPeriod: (json['discharged_period'] as num?)?.toInt() ?? 0,
      casesToday: (json['cases_today'] as num?)?.toInt() ?? 0,
      avgLosDays: (json['avg_los_days'] as num?)?.toDouble(),
      casesPerDay: (json['cases_per_day'] as List<dynamic>? ?? [])
          .map((e) => DailyCount.fromJson(e as Map<String, dynamic>))
          .toList(),
      weekdayWorkload: (json['weekday_workload'] as List<dynamic>? ?? [])
          .map((e) => LabeledCount.fromJson(e as Map<String, dynamic>, labelKey: 'label'))
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
      pendingOrdersCount: (json['pending_orders_count'] as num?)?.toInt() ?? 0,
      ordersOverdueCount: (json['orders_overdue_count'] as num?)?.toInt() ?? 0,
      ordersTurnaround: (json['orders_turnaround'] as List<dynamic>? ?? [])
          .map((e) => OrderTurnaround.fromJson(e as Map<String, dynamic>))
          .toList(),
      commitmentsOpen: (json['commitments_open'] as num?)?.toInt() ?? 0,
      commitmentsOverdue: (json['commitments_overdue'] as num?)?.toInt() ?? 0,
      commitmentsDonePeriod: (json['commitments_done_period'] as num?)?.toInt() ?? 0,
      complicationsOpen: (json['complications_open'] as num?)?.toInt() ?? 0,
      complicationsResolvedPeriod: (json['complications_resolved_period'] as num?)?.toInt() ?? 0,
      avgComplicationResolutionHours: (json['avg_complication_resolution_hours'] as num?)?.toDouble(),
      sourceMix: (json['source_mix'] as List<dynamic>? ?? [])
          .map((e) => LabeledCount.fromJson(e as Map<String, dynamic>, labelKey: 'label'))
          .toList(),
      doctorWorkload: (json['doctor_workload'] as List<dynamic>? ?? [])
          .map((e) => DoctorWorkload.fromJson(e as Map<String, dynamic>))
          .toList(),
      activeDoctorsCount: (json['active_doctors_count'] as num?)?.toInt() ?? 0,
    );
  }
}
