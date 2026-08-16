/// قسم/وحدة من [app_list_units] — للاستخدام في قائمة اختيار "يتحجز في أنهي قسم".
class UnitInfo {
  const UnitInfo({required this.id, required this.key, required this.name});

  final String id;
  final String key;
  final String name;

  factory UnitInfo.fromJson(Map<String, dynamic> json) {
    return UnitInfo(
      id: json['id']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}
