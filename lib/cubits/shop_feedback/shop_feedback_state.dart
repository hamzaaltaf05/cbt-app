import '../../models/shop_feedback.dart';

enum FeedbackFilter { all, suggestions, feedback }

class ShopFeedbackState {
  const ShopFeedbackState({
    this.feedbacks = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.filter = FeedbackFilter.all,
    this.errorMessage,
  });

  final List<ShopFeedback> feedbacks;
  final bool isLoading;
  final bool isSubmitting;
  final FeedbackFilter filter;
  final String? errorMessage;

  /// Returns the feed items filtered by the active tab filter, sorted by score descending.
  List<ShopFeedback> get filteredFeedbacks {
    final list = switch (filter) {
      FeedbackFilter.all => List<ShopFeedback>.from(feedbacks),
      FeedbackFilter.suggestions =>
        feedbacks.where((f) => f.type == FeedbackType.suggestion).toList(),
      FeedbackFilter.feedback =>
        feedbacks.where((f) => f.type == FeedbackType.feedback).toList(),
    };

    list.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return b.createdAt.compareTo(a.createdAt);
    });

    return list;
  }

  ShopFeedbackState copyWith({
    List<ShopFeedback>? feedbacks,
    bool? isLoading,
    bool? isSubmitting,
    FeedbackFilter? filter,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ShopFeedbackState(
      feedbacks: feedbacks ?? this.feedbacks,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      filter: filter ?? this.filter,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
