/// مهمة على أوردر معيّن للممرض/ة — من [app_nurse_task_list]، أقل قدر لازم بس
/// (اسم المريض/القسم/المهمة) مش كارت المريض الكامل.
class NurseTask {
  const NurseTask({
    required this.orderId,
    required this.encounterId,
    required this.patientName,
    required this.handle,
    required this.unit,
    required this.category,
    required this.name,
    required this.taskStatus,
    required this.assignedAt,
    required this.assignedBy,
  });

  final String orderId;
  final String encounterId;
  final String patientName;
  final String? handle;
  final String? unit;
  final String category;
  final String name;
  final String taskStatus; // assigned | accepted | in_progress | completed
  final DateTime? assignedAt;
  final String? assignedBy;

  bool get isAssigned => taskStatus == 'assigned';
  bool get isAccepted => taskStatus == 'accepted';
  bool get isInProgress => taskStatus == 'in_progress';
  bool get isCompleted => taskStatus == 'completed';

  factory NurseTask.fromJson(Map<String, dynamic> json) {
    return NurseTask(
      orderId: json['order_id']?.toString() ?? '',
      encounterId: json['encounter_id']?.toString() ?? '',
      patientName: json['patient_name']?.toString() ?? '',
      handle: json['handle']?.toString(),
      unit: json['unit']?.toString(),
      category: json['category']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      taskStatus: json['task_status']?.toString() ?? 'assigned',
      assignedAt: DateTime.tryParse(json['assigned_at']?.toString() ?? '')?.toLocal(),
      assignedBy: json['assigned_by']?.toString(),
    );
  }
}

/// نتيجة [app_list_nurses] — للقايمة اللي الدكتور يختار منها لما يعيّن مهمة.
class NurseInfo {
  const NurseInfo({required this.staffId, required this.fullName});

  final String staffId;
  final String fullName;

  factory NurseInfo.fromJson(Map<String, dynamic> json) {
    return NurseInfo(
      staffId: json['staff_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
    );
  }
}
