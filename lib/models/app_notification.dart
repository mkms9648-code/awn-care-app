/// صف من app_notifications_list — أخبار من الإدارة أو تنبيه تلقائي لاقتراب
/// انتهاء حد الباقة.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String title;
  final String body;
  final String kind;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'announcement',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'].toString())?.toLocal() : null,
    );
  }
}
