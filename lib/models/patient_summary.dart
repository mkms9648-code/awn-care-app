/// Full patient details from [app_patient_summary] — matches the real
/// Postgres function's jsonb shape exactly.
class PatientSummary {
  const PatientSummary({
    required this.patient,
    required this.encounter,
    required this.latestVitals,
    required this.openOrders,
    required this.activeMedications,
    required this.openCommitments,
    required this.openComplications,
    required this.recentNotes,
    required this.attachments,
  });

  final PatientInfo patient;
  final EncounterInfo encounter;
  final List<VitalReading> latestVitals;
  final List<OrderInfo> openOrders;
  final List<MedicationInfo> activeMedications;
  final List<Commitment> openCommitments;
  final List<ComplicationInfo> openComplications;
  final List<NoteInfo> recentNotes;
  final List<AttachmentInfo> attachments;

  factory PatientSummary.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) fromJson) {
      return (json[key] as List<dynamic>? ?? [])
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return PatientSummary(
      patient: PatientInfo.fromJson(json['patient'] as Map<String, dynamic>? ?? {}),
      encounter: EncounterInfo.fromJson(json['encounter'] as Map<String, dynamic>? ?? {}),
      latestVitals: list('latest_vitals', VitalReading.fromJson),
      openOrders: list('open_orders', OrderInfo.fromJson),
      activeMedications: list('active_medications', MedicationInfo.fromJson),
      openCommitments: list('open_commitments', Commitment.fromJson),
      openComplications: list('open_complications', ComplicationInfo.fromJson),
      recentNotes: list('recent_notes', NoteInfo.fromJson),
      attachments: list('attachments', AttachmentInfo.fromJson),
    );
  }
}

class PatientInfo {
  const PatientInfo({
    required this.id,
    required this.mrn,
    required this.name,
    required this.sex,
    required this.birthYear,
    required this.allergies,
    required this.chronicConditions,
  });

  final String id;
  final String mrn;
  final String name;
  final String? sex;
  final int? birthYear;
  final List<String> allergies;
  final List<String> chronicConditions;

  factory PatientInfo.fromJson(Map<String, dynamic> json) {
    return PatientInfo(
      id: json['id']?.toString() ?? '',
      mrn: json['mrn']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      sex: json['sex']?.toString(),
      birthYear: (json['birth_year'] as num?)?.toInt(),
      allergies: (json['allergies'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      chronicConditions:
          (json['chronic_conditions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class EncounterInfo {
  const EncounterInfo({
    required this.id,
    required this.status,
    required this.source,
    required this.openedAt,
    required this.dischargedAt,
    required this.unit,
    required this.attending,
    required this.handle,
  });

  final String id;
  final String status;
  final String source;
  final DateTime? openedAt;
  final DateTime? dischargedAt;
  final String? unit;
  final String? attending;
  final String? handle;

  factory EncounterInfo.fromJson(Map<String, dynamic> json) {
    return EncounterInfo(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      source: json['source']?.toString() ?? 'ed',
      openedAt: DateTime.tryParse(json['opened_at']?.toString() ?? '')?.toLocal(),
      dischargedAt: DateTime.tryParse(json['discharged_at']?.toString() ?? '')?.toLocal(),
      unit: json['unit']?.toString(),
      attending: json['attending']?.toString(),
      handle: json['handle']?.toString(),
    );
  }
}

class VitalReading {
  const VitalReading({
    required this.metric,
    required this.value,
    required this.unit,
    required this.measuredAt,
    required this.eventId,
  });

  final String metric;
  final num value;
  final String? unit;
  final DateTime measuredAt;
  final int? eventId;

  factory VitalReading.fromJson(Map<String, dynamic> json) {
    return VitalReading(
      metric: json['metric']?.toString() ?? '',
      value: (json['value'] as num?) ?? 0,
      unit: json['unit']?.toString(),
      measuredAt: DateTime.tryParse(json['measured_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      eventId: (json['event_id'] as num?)?.toInt(),
    );
  }
}

class OrderInfo {
  const OrderInfo({
    required this.id,
    required this.category,
    required this.name,
    required this.orderedAt,
    required this.orderedBy,
    required this.status,
    required this.resolvedAt,
    required this.resolvedBy,
  });

  final String id;
  final String category;
  final String name;
  final DateTime? orderedAt;
  final String? orderedBy;
  final String status;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  factory OrderInfo.fromJson(Map<String, dynamic> json) {
    return OrderInfo(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      orderedAt: DateTime.tryParse(json['ordered_at']?.toString() ?? '')?.toLocal(),
      orderedBy: json['ordered_by']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      resolvedAt: DateTime.tryParse(json['resolved_at']?.toString() ?? '')?.toLocal(),
      resolvedBy: json['resolved_by']?.toString(),
    );
  }
}

class MedicationInfo {
  const MedicationInfo({
    required this.id,
    required this.name,
    required this.dose,
    required this.route,
    required this.frequency,
  });

  final String id;
  final String name;
  final String? dose;
  final String? route;
  final String? frequency;

  factory MedicationInfo.fromJson(Map<String, dynamic> json) {
    return MedicationInfo(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      dose: json['dose']?.toString(),
      route: json['route']?.toString(),
      frequency: json['frequency']?.toString(),
    );
  }
}

class Commitment {
  const Commitment({
    required this.id,
    required this.text,
    required this.dueAt,
    required this.isOverdue,
    required this.owner,
  });

  final String id;
  final String text;
  final DateTime? dueAt;
  final bool isOverdue;
  final String? owner;

  factory Commitment.fromJson(Map<String, dynamic> json) {
    return Commitment(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      dueAt: DateTime.tryParse(json['due_at']?.toString() ?? '')?.toLocal(),
      isOverdue: json['overdue'] == true,
      owner: json['owner']?.toString(),
    );
  }
}

class ComplicationInfo {
  const ComplicationInfo({required this.id, required this.description, required this.openedAt});

  final String id;
  final String description;
  final DateTime? openedAt;

  factory ComplicationInfo.fromJson(Map<String, dynamic> json) {
    return ComplicationInfo(
      id: json['id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      openedAt: DateTime.tryParse(json['opened_at']?.toString() ?? '')?.toLocal(),
    );
  }
}

class NoteInfo {
  const NoteInfo({required this.kind, required this.body, required this.at});

  final String kind;
  final String body;
  final DateTime? at;

  factory NoteInfo.fromJson(Map<String, dynamic> json) {
    return NoteInfo(
      kind: json['kind']?.toString() ?? 'note',
      body: json['body']?.toString() ?? '',
      at: DateTime.tryParse(json['at']?.toString() ?? '')?.toLocal(),
    );
  }
}

class AttachmentInfo {
  const AttachmentInfo({
    required this.id,
    required this.kind,
    required this.storagePath,
    required this.caption,
    required this.uploadedAt,
  });

  final String id;
  final String kind;
  final String storagePath;
  final String? caption;
  final DateTime? uploadedAt;

  factory AttachmentInfo.fromJson(Map<String, dynamic> json) {
    return AttachmentInfo(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'image',
      storagePath: json['storage_path']?.toString() ?? '',
      caption: json['caption']?.toString(),
      uploadedAt: DateTime.tryParse(json['uploaded_at']?.toString() ?? '')?.toLocal(),
    );
  }
}

/// A staged (not-yet-committed) vitals reading — from [app_stage_vitals] /
/// [app_latest_pending]. Shown to the doctor as an editable review before the
/// final [app_commit_vitals] write.
class PendingVitals {
  const PendingVitals({
    required this.pendingId,
    required this.encounterId,
    required this.readings,
    required this.measuredAt,
  });

  final String pendingId;
  final String encounterId;
  final List<Map<String, dynamic>> readings;
  final DateTime measuredAt;

  factory PendingVitals.fromJson(Map<String, dynamic> json) {
    return PendingVitals(
      pendingId: json['pending_id'].toString(),
      encounterId: json['encounter_id'].toString(),
      readings: (json['readings'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      measuredAt: DateTime.tryParse(json['measured_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}

class VitalSeriesPoint {
  const VitalSeriesPoint({required this.timestamp, required this.value});

  final DateTime timestamp;
  final double value;

  factory VitalSeriesPoint.fromJson(Map<String, dynamic> json) {
    return VitalSeriesPoint(
      timestamp: DateTime.tryParse(json['at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      value: (json['value'] as num?)?.toDouble() ?? 0,
    );
  }
}
