/// نتيجة app_plan_usage — استخدام الباقة الحالي لكل موديول عليه حد، زائد
/// العدّاد التنازلي لأيام التجديد.
class PlanUsage {
  const PlanUsage({required this.daysUntilRenewal, required this.modules});

  final int daysUntilRenewal;
  final List<ModuleUsage> modules;

  factory PlanUsage.fromJson(Map<String, dynamic> json) {
    return PlanUsage(
      daysUntilRenewal: (json['days_until_renewal'] as num?)?.toInt() ?? 0,
      modules: (json['modules'] as List<dynamic>? ?? [])
          .map((e) => ModuleUsage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ModuleUsage {
  const ModuleUsage({required this.moduleKey, required this.maxPerPeriod, required this.used});

  final String moduleKey;
  final int maxPerPeriod;
  final int used;

  int get remaining => (maxPerPeriod - used).clamp(0, maxPerPeriod);
  double get fraction => maxPerPeriod == 0 ? 0 : (used / maxPerPeriod).clamp(0, 1);

  factory ModuleUsage.fromJson(Map<String, dynamic> json) {
    return ModuleUsage(
      moduleKey: json['module_key']?.toString() ?? '',
      maxPerPeriod: (json['max_per_period'] as num?)?.toInt() ?? 0,
      used: (json['used'] as num?)?.toInt() ?? 0,
    );
  }
}
