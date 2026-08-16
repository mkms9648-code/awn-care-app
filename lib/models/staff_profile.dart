/// Physician profile returned by [app_resolve_staff] (extended in migration
/// 002_awn_care_profile.sql to include specialty/license/org/plan on top of
/// the original staff_id/org_id/workspace_id/role/full_name/features).
class StaffProfile {
  const StaffProfile({
    required this.staffId,
    required this.name,
    required this.role,
    required this.workspaceId,
    required this.specialty,
    required this.licenseNumber,
    required this.hospitalName,
    required this.enabledFeatures,
    required this.subscription,
  });

  final String staffId;
  final String name;
  final String role;
  final String workspaceId;
  final String? specialty;
  final String? licenseNumber;
  final String? hospitalName;
  final List<String> enabledFeatures;
  final SubscriptionInfo subscription;

  factory StaffProfile.fromJson(Map<String, dynamic> json) {
    final features =
        (json['features'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
    return StaffProfile(
      staffId: json['staff_id']?.toString() ?? '',
      name: json['full_name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      workspaceId: json['workspace_id']?.toString() ?? '',
      specialty: json['specialty']?.toString(),
      licenseNumber: json['license_no']?.toString(),
      hospitalName: json['org_name']?.toString(),
      enabledFeatures: features,
      subscription: SubscriptionInfo(
        planName: json['plan_name']?.toString() ?? 'Standard',
        isActive: json['plan_active'] == true,
        enabledFeatures: features,
      ),
    );
  }
}

/// Note: there's no subscription-expiration date tracked anywhere in the
/// current backend schema (plans/workspaces have no expiry column), so we
/// never show a fabricated one — this section only reflects real data.
class SubscriptionInfo {
  const SubscriptionInfo({
    required this.planName,
    required this.isActive,
    required this.enabledFeatures,
  });

  final String planName;
  final bool isActive;
  final List<String> enabledFeatures;

  String get statusLabel => isActive ? 'Active' : 'Inactive';
}
