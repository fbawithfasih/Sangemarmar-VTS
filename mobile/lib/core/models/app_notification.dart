class AppNotification {
  final String id;
  final String type;
  final String message;
  final String? entityId;
  final String? actorName;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.message,
    this.entityId,
    this.actorName,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        type: json['type'] as String,
        message: json['message'] as String,
        entityId: json['entityId'] as String?,
        actorName: json['actorName'] as String?,
        isRead: json['isRead'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );

  String get typeIcon {
    switch (type) {
      case 'VEHICLE_ENTRY': return '🚗';
      case 'SALE': return '💰';
      case 'PAYMENT': return '💳';
      case 'COMMISSION': return '✏️';
      default: return '🔔';
    }
  }
}
