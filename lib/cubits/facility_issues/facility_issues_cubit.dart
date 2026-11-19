import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cbt_app/models/facility_issue.dart';
import 'package:cbt_app/cubits/facility_issues/facility_issues_state.dart';
import 'package:cbt_app/services/voting_repository.dart';

class FacilityIssuesCubit extends Cubit<FacilityIssuesState> {
  final SupabaseClient _client;
  final VotingRepository _votingRepository;
  RealtimeChannel? _channel;

  FacilityIssuesCubit(this._client, {VotingRepository? votingRepository})
      : _votingRepository = votingRepository ?? VotingRepository(client: _client),
        super(const FacilityIssuesState()) {
    loadIssues();
    _subscribeRealtime();
  }

  Future<void> loadIssues() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final rows = await _client
          .from('facility_issues')
          .select('*, profiles!facility_issues_reported_by_key(full_name)')
          .order('created_at', ascending: false);

      final userVotes = await _votingRepository.fetchUserVotes(
        targetType: 'facility_issue',
      );

      final issues = rows.map((row) {
        final id = row['id'] as String;
        final vote = userVotes[id] ?? 0;
        return FacilityIssue.fromMap(row, userVote: vote);
      }).toList();

      issues.sort(_compareIssues);

      final Map<String, String> reporterNames = {};
      for (final row in rows) {
        final issue = FacilityIssue.fromMap(row);
        final profile = row['profiles'] as Map<String, dynamic>?;
        if (profile != null) {
          reporterNames[issue.reportedBy] =
              profile['full_name'] as String? ?? 'Unknown';
        }
      }

      emit(state.copyWith(
        issues: issues,
        reporterNames: reporterNames,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load facility issues: $e',
      ));
    }
  }

  /// Comparator: highest score first; ties broken by newest first.
  static int _compareIssues(FacilityIssue a, FacilityIssue b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) return scoreCompare;
    return b.createdAt.compareTo(a.createdAt);
  }

  void setFilter(IssueStatus? status) {
    if (status == null) {
      emit(state.copyWith(clearFilter: true));
    } else {
      emit(state.copyWith(filterStatus: status));
    }
  }

  /// Instant optimistic vote toggle on facility issues
  Future<void> castVote(FacilityIssue issue, int requestedVote) async {
    final previousIssues = List<FacilityIssue>.from(state.issues);
    final nextVote = issue.userVote == requestedVote ? 0 : requestedVote;

    int newUp = issue.upvotesCount;
    int newDown = issue.downvotesCount;

    if (issue.userVote == 1) newUp--;
    if (issue.userVote == -1) newDown--;

    if (nextVote == 1) newUp++;
    if (nextVote == -1) newDown++;

    newUp = newUp < 0 ? 0 : newUp;
    newDown = newDown < 0 ? 0 : newDown;

    final updatedIssue = issue.copyWith(
      userVote: nextVote,
      upvotesCount: newUp,
      downvotesCount: newDown,
    );

    final updatedIssues = state.issues.map((i) {
      return i.id == issue.id ? updatedIssue : i;
    }).toList();
    updatedIssues.sort(_compareIssues);

    emit(state.copyWith(issues: updatedIssues));

    try {
      final res = await _votingRepository.castVote(
        targetType: 'facility_issue',
        targetId: issue.id,
        vote: nextVote,
      );

      if (res.isNotEmpty && res['upvotes'] != null && res['downvotes'] != null) {
        final confirmedIssues = state.issues.map((i) {
          if (i.id == issue.id) {
            return i.copyWith(
              upvotesCount: (res['upvotes'] as num).toInt(),
              downvotesCount: (res['downvotes'] as num).toInt(),
              userVote: (res['user_vote'] as num).toInt(),
            );
          }
          return i;
        }).toList();
        confirmedIssues.sort(_compareIssues);
        emit(state.copyWith(issues: confirmedIssues));
      }
    } catch (e) {
      emit(state.copyWith(
        issues: previousIssues,
        errorMessage: 'Failed to update vote: $e',
      ));
    }
  }

  Future<bool> createIssue({
    required String title,
    required String description,
    XFile? image,
    bool isPrivate = false,
  }) async {
    emit(state.copyWith(isLoading: true));

    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      String? photoUrl;
      if (image != null) {
        final ext = image.name.split('.').last;
        final filename = '${DateTime.now().millisecondsSinceEpoch}_${user.id}.$ext';
        final file = File(image.path);

        await _client.storage.from('facility-photos').upload(
              filename,
              file,
              fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
            );

        photoUrl = _client.storage.from('facility-photos').getPublicUrl(filename);
      }

      final inserted = await _client.from('facility_issues').insert({
        'title': title,
        'description': description,
        'reported_by': user.id,
        'image_url': photoUrl,
        'status': 'pending',
        'is_private': isPrivate,
      }).select().single();

      final newIssue = FacilityIssue.fromMap(inserted);
      final updatedList = [newIssue, ...state.issues]..sort(_compareIssues);
      emit(state.copyWith(
        issues: updatedList,
        isLoading: false,
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to create issue: $e',
      ));
      return false;
    }
  }

  /// Optimistic status and admin response update (Cross-screen instant sync)
  Future<bool> updateIssue({
    required String id,
    required IssueStatus status,
    String? adminResponse,
  }) async {
    final previousIssues = List<FacilityIssue>.from(state.issues);

    // Instant local update
    final updated = state.issues.map((i) {
      if (i.id == id) {
        return i.copyWith(
          status: status,
          adminResponse: adminResponse ?? i.adminResponse,
          updatedAt: DateTime.now(),
        );
      }
      return i;
    }).toList();

    emit(state.copyWith(issues: updated));

    try {
      final updates = <String, dynamic>{
        'status': status.dbValue,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (adminResponse != null) {
        updates['admin_response'] = adminResponse;
      }

      await _client.from('facility_issues').update(updates).eq('id', id);
      return true;
    } catch (e) {
      emit(state.copyWith(
        issues: previousIssues,
        errorMessage: 'Failed to update issue: $e',
      ));
      return false;
    }
  }

  /// Alias for backward compatibility
  Future<bool> updateIssueStatus({
    required String id,
    required IssueStatus status,
    String? adminResponse,
  }) =>
      updateIssue(id: id, status: status, adminResponse: adminResponse);

  /// Request reporter to delete issue (for office admins)
  Future<bool> requestDeletion(String id) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final previousIssues = List<FacilityIssue>.from(state.issues);

    final updated = state.issues.map((i) {
      if (i.id == id) {
        return i.copyWith(
          deletionRequestedBy: user.id,
          deletionRequestedAt: DateTime.now(),
        );
      }
      return i;
    }).toList();

    emit(state.copyWith(issues: updated));

    try {
      await _client.from('facility_issues').update({
        'deletion_requested_by': user.id,
        'deletion_requested_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      emit(state.copyWith(
        issues: previousIssues,
        errorMessage: 'Failed to request deletion: $e',
      ));
      return false;
    }
  }

  Future<bool> deleteIssue(String id) async {
    final previousIssues = List<FacilityIssue>.from(state.issues);

    final updated = state.issues.where((i) => i.id != id).toList();
    emit(state.copyWith(issues: updated));

    try {
      await _client.from('facility_issues').delete().eq('id', id);
      return true;
    } catch (e) {
      emit(state.copyWith(
        issues: previousIssues,
        errorMessage: 'Failed to delete issue: $e',
      ));
      return false;
    }
  }

  void _subscribeRealtime() {
    _channel = _client.channel('public:facility_issues');
    _channel?.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'facility_issues',
      callback: (payload) {
        loadIssues();
      },
    );
    _channel?.subscribe();
  }

  @override
  Future<void> close() {
    if (_channel != null) {
      _client.removeChannel(_channel!);
    }
    return super.close();
  }
}
