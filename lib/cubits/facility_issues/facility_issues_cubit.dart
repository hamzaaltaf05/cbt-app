import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cbt_app/models/facility_issue.dart';
import 'package:cbt_app/cubits/facility_issues/facility_issues_state.dart';

class FacilityIssuesCubit extends Cubit<FacilityIssuesState> {
  final SupabaseClient _client;
  RealtimeChannel? _channel;

  FacilityIssuesCubit(this._client) : super(const FacilityIssuesState()) {
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

      final issues = rows.map((row) => FacilityIssue.fromMap(row)).toList();
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

  void setFilter(IssueStatus? status) {
    if (status == null) {
      emit(state.copyWith(clearFilter: true));
    } else {
      emit(state.copyWith(filterStatus: status));
    }
  }

  Future<bool> createIssue({
    required String title,
    required String description,
    XFile? image,
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
      }).select().single();

      final newIssue = FacilityIssue.fromMap(inserted);
      emit(state.copyWith(
        issues: [newIssue, ...state.issues],
        isLoading: false,
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to report issue: $e',
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
