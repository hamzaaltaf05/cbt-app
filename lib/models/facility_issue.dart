enum IssueStatus { pending, inProgress, resolved, rejected }

class FacilityIssue {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final IssueStatus status;
  final String reportedBy;
  final String? adminResponse;
  final DateTime createdAt;

  FacilityIssue({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.status,
    required this.reportedBy,
    this.adminResponse,
    required this.createdAt,
  });

  factory FacilityIssue.fromMap(Map<String, dynamic> map) {
    return FacilityIssue(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      imageUrl: map['image_url'] as String?,
      status: _parseIssueStatus(map['status'] as String?),
      reportedBy: map['reported_by'] as String,
      adminResponse: map['admin_response'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'status': status.name,
      'reported_by': reportedBy,
      'admin_response': adminResponse,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static IssueStatus _parseIssueStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'in_progress':
        return IssueStatus.inProgress;
      case 'resolved':
        return IssueStatus.resolved;
      case 'rejected':
        return IssueStatus.rejected;
      case 'pending':
      default:
        return IssueStatus.pending;
    }
  }
}