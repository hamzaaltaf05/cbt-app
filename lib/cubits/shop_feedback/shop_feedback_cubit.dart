import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/shop_feedback.dart';
import '../../services/shop_feedback_repository.dart';
import 'shop_feedback_state.dart';

class ShopFeedbackCubit extends Cubit<ShopFeedbackState> {
  final ShopFeedbackRepository _repository;
  RealtimeChannel? _subscription;

  ShopFeedbackCubit({ShopFeedbackRepository? repository})
      : _repository = repository ?? ShopFeedbackRepository(),
        super(const ShopFeedbackState()) {
    loadFeedback();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _subscription = _repository.subscribeToChanges(
      onDataChange: () => loadFeedback(isSilent: true),
    );
  }

  /// Comparator: highest score first; ties broken by newest first.
  static int _compareFeedbacks(ShopFeedback a, ShopFeedback b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) return scoreCompare;
    return b.createdAt.compareTo(a.createdAt);
  }

  /// Loads all feedback posts. If [isSilent] is true, doesn't emit loading state (for background sync).
  Future<void> loadFeedback({bool isSilent = false}) async {
    if (!isSilent) {
      emit(state.copyWith(isLoading: true, clearError: true));
    }

    try {
      final items = await _repository.fetchFeedback();
      items.sort(_compareFeedbacks);
      emit(state.copyWith(
        feedbacks: items,
        isLoading: false,
        clearError: true,
      ));
    } catch (e) {
      if (!isSilent) {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load feedback: $e',
        ));
      }
    }
  }

  /// Sets the active filter tab ('All', 'Suggestions', 'Feedback').
  void setFilter(FeedbackFilter filter) {
    emit(state.copyWith(filter: filter));
  }

  /// Submits a new feedback or suggestion post.
  Future<bool> createFeedback({
    required FeedbackType type,
    required String title,
    required String description,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      final newItem = await _repository.createFeedback(
        type: type,
        title: title,
        description: description,
      );

      final updatedList = [newItem, ...state.feedbacks]..sort(_compareFeedbacks);
      emit(state.copyWith(
        feedbacks: updatedList,
        isSubmitting: false,
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to submit post: $e',
      ));
      return false;
    }
  }

  /// Responds to a post (Admins & Shop Managers).
  Future<bool> respondToFeedback({
    required String feedbackId,
    required String responseText,
  }) async {
    final previousFeedbacks = List<ShopFeedback>.from(state.feedbacks);

    // Optimistic local update of the response
    final updatedList = state.feedbacks.map((f) {
      if (f.id == feedbackId) {
        return f.copyWith(
          adminResponse: responseText,
          respondedAt: DateTime.now(),
        );
      }
      return f;
    }).toList();

    emit(state.copyWith(feedbacks: updatedList));

    try {
      await _repository.respondToFeedback(
        feedbackId: feedbackId,
        response: responseText,
      );
      return true;
    } catch (e) {
      // Revert if call fails
      emit(state.copyWith(
        feedbacks: previousFeedbacks,
        errorMessage: 'Failed to post response: $e',
      ));
      return false;
    }
  }

  /// Optimistically upvotes (1), downvotes (-1), or removes vote (0) with zero perceived latency.
  Future<void> castVote(ShopFeedback item, int requestedVote) async {
    final previousFeedbacks = List<ShopFeedback>.from(state.feedbacks);

    // Determine target vote: clicking an already selected vote toggles it to 0
    final nextVote = item.userVote == requestedVote ? 0 : requestedVote;

    // Calculate count adjustments
    int newUp = item.upvotesCount;
    int newDown = item.downvotesCount;

    // 1. Remove previous vote effect
    if (item.userVote == 1) newUp--;
    if (item.userVote == -1) newDown--;

    // 2. Apply new vote effect
    if (nextVote == 1) newUp++;
    if (nextVote == -1) newDown++;

    // Safety guard
    newUp = newUp < 0 ? 0 : newUp;
    newDown = newDown < 0 ? 0 : newDown;

    final updatedItem = item.copyWith(
      userVote: nextVote,
      upvotesCount: newUp,
      downvotesCount: newDown,
    );

    // Instant local UI state update
    final updatedFeedbacks = state.feedbacks.map((f) {
      return f.id == item.id ? updatedItem : f;
    }).toList();
    updatedFeedbacks.sort(_compareFeedbacks);

    emit(state.copyWith(feedbacks: updatedFeedbacks));

    // Persist to Supabase RPC
    try {
      final res = await _repository.castVote(
        feedbackId: item.id,
        vote: nextVote,
      );

      // Harmonize with server truth if returned
      if (res.isNotEmpty && res['upvotes'] != null && res['downvotes'] != null) {
        final confirmedFeedbacks = state.feedbacks.map((f) {
          if (f.id == item.id) {
            return f.copyWith(
              upvotesCount: (res['upvotes'] as num).toInt(),
              downvotesCount: (res['downvotes'] as num).toInt(),
              userVote: (res['user_vote'] as num).toInt(),
            );
          }
          return f;
        }).toList();
        confirmedFeedbacks.sort(_compareFeedbacks);
        emit(state.copyWith(feedbacks: confirmedFeedbacks));
      }
    } catch (e) {
      // Revert on failure
      emit(state.copyWith(
        feedbacks: previousFeedbacks,
        errorMessage: 'Failed to register vote. Reverted.',
      ));
    }
  }

  @override
  Future<void> close() {
    _subscription?.unsubscribe();
    return super.close();
  }
}
