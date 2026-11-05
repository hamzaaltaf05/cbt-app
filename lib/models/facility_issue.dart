import 'package:flutter/material.dart';

/// Status of a facility issue, as tracked in the `facility_issues.status`
/// column.
enum IssueStatus {
  pending, inProgress, resolved, rejected;

  String get dbValue => switch (this) {
        pending => 'pending',
        inProgress => 'in_progress',
        resolved => 'resolved',
        rejected => 'rejected',
      };

  String get label => switch (this) {
        pending => 'Pending',
        inProgress => 'In Progress',
        resolved => 'Resolved',
        rejected => 'Rejected',
      };

  Color get color => switch (this) {
        pending => Colors.orange,
        inProgress => Colors.blue,
        resolved => Colors.green,
        rejected => Colors.red,
      };

  static IssueStatus fromValue(String? value) => switch (value) {
        'in_progress' => inProgress,
        'resolved' => resolved,
        'rejected' => rejected,
        _ => pending,
      };
}

class FacilityIssue {
  const FacilityIssue({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.reportedBy,
    required this.createdAt,
    required this.adminResponse,
    this.photoPath,
    this.imageUrl,
    this.updatedAt,
    this.photos = const [],
    this.deletionRequestedBy,
    this.deletionRequestedAt,
  });

  final String id;
  final String title;
  final String description;
  final IssueStatus status;
  final String? photoPath;
  final String? imageUrl;
  final String? adminResponse;
  final String reportedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> photos;
  final String? deletionRequestedBy;
  final DateTime? deletionRequestedAt;

  bool get isAdminResponse => adminResponse != null;
  bool get isDeletionRequested => deletionRequestedBy != null;

  String get statusLabel => status.label;
  Color get statusColor => status.color;

  factory FacilityIssue.fromMap(Map<String, dynamic> map) {
    var raw = map['photos'];
    final photos = <String>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is String) photos.add(item);
      }
    }
    return FacilityIssue(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? '',
      description: map['description'] as String,
      status: IssueStatus.fromValue(map['status'] as String?),
      reportedBy: (map['reported_by'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      adminResponse: map['admin_response'] as String?,
      photoPath: map['photo_path'] as String?,
      imageUrl: map['image_url'] as String?,
      updatedAt: _parseDateTime(map['updated_at']),
      photos: photos,
      deletionRequestedBy: map['deletion_requested_by'] as String?,
      deletionRequestedAt: _parseDateTime(map['deletion_requested_at']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    final raw = value as String?;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    return 'FacilityIssue(id: $id, description: ${description.substring(0, description.length > 30 ? 30 : description.length)}..., status: $status, reportedBy: $reportedBy, createdAt: ${_formatDate(createdAt)}, photos: ${photos.length}, adminResponse: $adminResponse)';
  }
}