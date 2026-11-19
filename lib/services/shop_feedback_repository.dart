import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shop_feedback.dart';
import 'voting_repository.dart';

/// Repository for CRUD operations and interactions with Honour Shop feedback and suggestions.
class ShopFeedbackRepository {
  final SupabaseClient _client;
  final VotingRepository _votingRepository;

  ShopFeedbackRepository({
    SupabaseClient? client,
    VotingRepository? votingRepository,
  })  : _client = client ?? Supabase.instance.client,
        _votingRepository = votingRepository ?? VotingRepository(client: client);

  /// Fetches all feedback and suggestion posts, merging author profiles and current user's votes.
  Future<List<ShopFeedback>> fetchFeedback() async {
    final rows = await _client
        .from('shop_feedback')
        .select('*, profiles!shop_feedback_user_id_fkey(full_name)')
        .order('created_at', ascending: false);

    // Fetch user votes in parallel
    final userVotes = await _votingRepository.fetchUserVotes(
      targetType: 'shop_feedback',
    );

    return rows.map((row) {
      final id = row['id'] as String;
      final userVote = userVotes[id] ?? 0;
      return ShopFeedback.fromMap(row, userVote: userVote);
    }).toList();
  }

  /// Creates a new suggestion or feedback post.
  Future<ShopFeedback> createFeedback({
    required FeedbackType type,
    required String title,
    required String description,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final inserted = await _client
        .from('shop_feedback')
        .insert({
          'user_id': user.id,
          'type': type.dbValue,
          'title': title.trim(),
          'description': description.trim(),
        })
        .select('*, profiles!shop_feedback_user_id_fkey(full_name)')
        .single();

    return ShopFeedback.fromMap(inserted, userVote: 0);
  }

  /// Adds or updates an admin response on a feedback post (Admins & Shop Managers only).
  Future<ShopFeedback> respondToFeedback({
    required String feedbackId,
    required String response,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final updated = await _client
        .from('shop_feedback')
        .update({
          'admin_response': response.trim(),
          'responded_by': user.id,
          'responded_at': DateTime.now().toIso8601String(),
        })
        .eq('id', feedbackId)
        .select('*, profiles!shop_feedback_user_id_fkey(full_name)')
        .single();

    return ShopFeedback.fromMap(updated);
  }

  /// Casts an upvote (1), downvote (-1), or removes vote (0) on a feedback post.
  Future<Map<String, dynamic>> castVote({
    required String feedbackId,
    required int vote,
  }) {
    return _votingRepository.castVote(
      targetType: 'shop_feedback',
      targetId: feedbackId,
      vote: vote,
    );
  }

  /// Subscribes to realtime changes on the `shop_feedback` table.
  RealtimeChannel subscribeToChanges({required void Function() onDataChange}) {
    final channel = _client.channel('public:shop_feedback');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shop_feedback',
          callback: (_) => onDataChange(),
        )
        .subscribe();
    return channel;
  }
}
