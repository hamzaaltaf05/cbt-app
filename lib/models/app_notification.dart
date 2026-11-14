/// A single in-app notification for one user.
///
/// Mirrors a row in the `public.notifications` table. The optional
/// [refType] / [refId] pair is the deep-link target: when present the
/// notification screen can navigate to the related screen (e.g. a facility
/// issue detail view).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.body,
    this.refType,
    this.refId,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String userId;

  /// Machine type, e.g. `facility_reported`, `shop_item_added`.
  final String type;

  final String title;
  final String? body;

  /// Optional deep-link target (e.g. `facility_issue`).
  final String? refType;
  final String? refId;

  final bool isRead;
  final DateTime createdAt;

  /// The related facility issue id, if this notification points at one.
  String? get facilityIssueId =>
      refType == 'facility_issue' ? refId : null;

  /// True when tapping this notification should open the facility detail.
  bool get isFacility => refType == 'facility_issue';

  /// Human-friendly grouping label used for section headers.
  String get groupLabel {
    switch (type) {
      case 'facility_reported':
      case 'facility_status':
      case 'facility_deletion_requested':
      case 'facility_deleted':
        return 'Facility';
      case 'shop_item_added':
      case 'shop_item_updated':
      case 'shop_item_removed':
        return 'Shop';
      default:
        return 'General';
    }
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    final createdRaw = map['created_at'];
    final createdAt = createdRaw is DateTime
        ? createdRaw
        : DateTime.tryParse(createdRaw?.toString() ?? '') ??
            DateTime.now();

    return AppNotification(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      type: (map['type'] as String?) ?? 'general',
      title: (map['title'] as String?) ?? 'Notification',
      body: map['body'] as String?,
      refType: map['ref_type'] as String?,
      refId: map['ref_id'] as String?,
      isRead: (map['is_read'] as bool?) ?? false,
      createdAt: createdAt,
    );
  }
}
