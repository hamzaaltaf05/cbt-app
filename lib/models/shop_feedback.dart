import 'package:flutter/material.dart';

/// Type of shop feedback/suggestion post.
enum FeedbackType {
  suggestion('suggestion', 'Suggestion'),
  feedback('feedback', 'Feedback');

  const FeedbackType(this.dbValue, this.label);
  final String dbValue;
  final String label;

  Color get color => switch (this) {
        suggestion => const Color(0xFF2563EB), // Blue
        feedback => const Color(0xFF7C3AED),   // Purple
      };

  IconData get icon => switch (this) {
        suggestion => Icons.lightbulb_outline,
        feedback => Icons.rate_review_outlined,
      };

  static FeedbackType fromValue(String? value) => switch (value) {
        'feedback' => feedback,
        _ => suggestion,
      };
}

/// Model representing a single Honour Shop feedback or suggestion post.
class ShopFeedback {
  const ShopFeedback({
    required this.id,
    this.userId,
    this.authorName = 'Anonymous User',
    required this.type,
    required this.title,
    required this.description,
    this.adminResponse,
    this.respondedBy,
    this.respondedAt,
    this.upvotesCount = 0,
    this.downvotesCount = 0,
    this.userVote = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? userId;
  final String authorName;
  final FeedbackType type;
  final String title;
  final String description;
  final String? adminResponse;
  final String? respondedBy;
  final DateTime? respondedAt;
  final int upvotesCount;
  final int downvotesCount;
  final int userVote; // 1 (upvoted), -1 (downvoted), 0 (none)
  final DateTime createdAt;
  final DateTime updatedAt;

  int get score => upvotesCount - downvotesCount;
  bool get isResponded => adminResponse != null && adminResponse!.trim().isNotEmpty;

  ShopFeedback copyWith({
    String? id,
    String? userId,
    String? authorName,
    FeedbackType? type,
    String? title,
    String? description,
    String? adminResponse,
    String? respondedBy,
    DateTime? respondedAt,
    int? upvotesCount,
    int? downvotesCount,
    int? userVote,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShopFeedback(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      authorName: authorName ?? this.authorName,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      adminResponse: adminResponse ?? this.adminResponse,
      respondedBy: respondedBy ?? this.respondedBy,
      respondedAt: respondedAt ?? this.respondedAt,
      upvotesCount: upvotesCount ?? this.upvotesCount,
      downvotesCount: downvotesCount ?? this.downvotesCount,
      userVote: userVote ?? this.userVote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ShopFeedback.fromMap(
    Map<String, dynamic> map, {
    int userVote = 0,
    String? authorName,
  }) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    final resolvedAuthor = authorName ??
        (profile != null ? profile['full_name'] as String? : null) ??
        'User';

    return ShopFeedback(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      authorName: resolvedAuthor,
      type: FeedbackType.fromValue(map['type'] as String?),
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      adminResponse: map['admin_response'] as String?,
      respondedBy: map['responded_by'] as String?,
      respondedAt: map['responded_at'] != null
          ? DateTime.tryParse(map['responded_at'] as String)
          : null,
      upvotesCount: (map['upvotes_count'] as num?)?.toInt() ?? 0,
      downvotesCount: (map['downvotes_count'] as num?)?.toInt() ?? 0,
      userVote: userVote,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'type': type.dbValue,
      'title': title,
      'description': description,
      'admin_response': adminResponse,
      'responded_by': respondedBy,
      'responded_at': respondedAt?.toIso8601String(),
    };
  }
}
