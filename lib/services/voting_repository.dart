import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for managing Reddit-style upvoting/downvoting across entities.
class VotingRepository {
  final SupabaseClient _client;

  VotingRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Fetches the current authenticated user's votes for a specific target type
  /// ('facility_issue', 'shop_item', or 'shop_feedback').
  /// Returns a map of `targetId -> vote` (-1 or 1).
  Future<Map<String, int>> fetchUserVotes({
    required String targetType,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return {};

    try {
      final rows = await _client
          .from('entity_votes')
          .select('target_id, vote')
          .eq('user_id', user.id)
          .eq('target_type', targetType);

      final Map<String, int> votesMap = {};
      for (final row in rows) {
        final targetId = row['target_id'] as String?;
        final vote = (row['vote'] as num?)?.toInt();
        if (targetId != null && vote != null) {
          votesMap[targetId] = vote;
        }
      }
      return votesMap;
    } catch (e) {
      // Non-fatal: if user votes fail to fetch, defaults to unvoted (0)
      return {};
    }
  }

  /// Atomically casts, changes, or toggles a vote via Supabase RPC `cast_vote`.
  /// [vote]: 1 (upvote), -1 (downvote), or 0 (cancel/clear vote).
  ///
  /// Returns a map containing:
  /// `{ target_id, upvotes, downvotes, score, user_vote }`
  Future<Map<String, dynamic>> castVote({
    required String targetType,
    required String targetId,
    required int vote,
  }) async {
    final response = await _client.rpc(
      'cast_vote',
      params: {
        'p_target_type': targetType,
        'p_target_id': targetId,
        'p_vote': vote,
      },
    );

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    return {};
  }
}
