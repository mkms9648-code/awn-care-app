/// Case card returned by [app_encounter_list] — matches the real Postgres
/// function's `results[]` shape exactly:
/// { encounter_id, handle, patient, mrn, unit, attending, days_open, detail }
class Encounter {
  const Encounter({
    required this.encounterId,
    required this.handle,
    required this.patientName,
    required this.mrn,
    required this.unit,
    required this.attending,
    required this.openDays,
    this.detail,
    this.dischargedAt,
    this.openedAt,
  });

  final String encounterId;
  final String? handle;
  final String patientName;
  final String mrn;
  final String? unit;
  final String? attending;
  final int openDays;
  final DateTime? dischargedAt;
  final DateTime? openedAt;

  /// Shape depends on the active filter — only populated for
  /// pending_orders / overdue_commitments / open_complications.
  final List<dynamic>? detail;

  int get detailCount => detail?.length ?? 0;

  factory Encounter.fromJson(Map<String, dynamic> json) {
    return Encounter(
      encounterId: json['encounter_id']?.toString() ?? '',
      handle: json['handle']?.toString(),
      patientName: json['patient']?.toString() ?? 'Unknown',
      mrn: json['mrn']?.toString() ?? '',
      unit: json['unit']?.toString(),
      attending: json['attending']?.toString(),
      openDays: (json['days_open'] as num?)?.toInt() ?? 0,
      detail: json['detail'] as List<dynamic>?,
      dischargedAt: json['discharged_at'] != null
          ? DateTime.tryParse(json['discharged_at'].toString())?.toLocal()
          : null,
      openedAt: json['opened_at'] != null
          ? DateTime.tryParse(json['opened_at'].toString())?.toLocal()
          : null,
    );
  }
}

/// Filter options for the ED / Rounds board — values must match
/// app_encounter_list's p_filter exactly.
enum EncounterFilter {
  all('all', 'All'),
  mine('mine', 'My Cases'),
  pendingOrders('pending_orders', 'Pending Orders'),
  overdueCommitments('overdue_commitments', 'Overdue Commitments'),
  vitalsStale('vitals_stale', 'Stale Vitals'),
  openComplications('open_complications', 'Open Complications'),
  discharged('discharged', 'Discharged');

  const EncounterFilter(this.value, this.label);
  final String value;
  final String label;

  /// Whether this filter's `detail` array is meaningful to show as a badge.
  bool get hasDetail =>
      this == pendingOrders || this == overdueCommitments || this == openComplications;

  /// Filters shown as chips on the active board — `discharged` gets its own
  /// dedicated screen instead (see [DischargedListScreen]).
  static const chipFilters = [
    all,
    mine,
    pendingOrders,
    overdueCommitments,
    vitalsStale,
    openComplications,
  ];
}
