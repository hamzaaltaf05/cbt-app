import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cbt_app/models/app_notification.dart';
import 'package:cbt_app/cubits/notifications/notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  final SupabaseClient _client;
  StreamSubscription<AuthState>? _authSub;
  RealtimeChannel? _channel;
  String? _subscribedUid;

  NotificationsCubit(this._client) : super(const NotificationsState()) {
    _init();
  }

  void _init() {
    refresh();
    _ensureRealtime();

    _authSub = _client.auth.onAuthStateChange.listen((event) {
      if (_client.auth.currentSession != null) {
        _ensureRealtime();
        refresh();
      } else {
        _channel?.unsubscribe();
        _channel = null;
        _subscribedUid = null;
        emit(const NotificationsState());
      }
    });
  }

  String? get userId => _client.auth.currentUser?.id;

  Future<void> refresh() async {
    final uid = userId;
    if (uid == null) return;

    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final rows = await _client
          .from('notifications')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(100);

      final list = rows.map((row) => AppNotification.fromMap(row)).toList();
      emit(state.copyWith(notifications: list, isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load notifications: $e',
      ));
    }
  }

  /// Optimistically marks a single notification as read and persists.
  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;

    final updated = state.notifications.map((n) {
      return n.id == notification.id ? _asRead(n) : n;
    }).toList();

    emit(state.copyWith(notifications: updated));

    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notification.id);
    } catch (e) {
      // Revert if failed
      refresh();
    }
  }

  /// Optimistically marks all as read and persists.
  Future<void> markAllRead() async {
    final uid = userId;
    if (uid == null || state.unreadCount == 0) return;

    final updated = state.notifications.map((n) => _asRead(n)).toList();
    emit(state.copyWith(notifications: updated));

    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', uid)
          .eq('is_read', false);
    } catch (e) {
      refresh();
    }
  }

  AppNotification _asRead(AppNotification notification) => AppNotification(
        id: notification.id,
        userId: notification.userId,
        type: notification.type,
        title: notification.title,
        body: notification.body,
        refType: notification.refType,
        refId: notification.refId,
        isRead: true,
        createdAt: notification.createdAt,
      );

  void _ensureRealtime() {
    final uid = userId;
    if (uid == null || uid == _subscribedUid) return;

    if (_channel != null) {
      _client.removeChannel(_channel!);
    }
    _subscribedUid = uid;

    final channel = _client.channel('notifications:$uid');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: uid,
      ),
      callback: (payload) {
        final newNotification = AppNotification.fromMap(payload.newRecord);
        if (state.notifications.any((n) => n.id == newNotification.id)) return;
        emit(state.copyWith(
          notifications: [newNotification, ...state.notifications],
        ));
      },
    );
    channel.subscribe();
    _channel = channel;
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    if (_channel != null) {
      _client.removeChannel(_channel!);
    }
    return super.close();
  }
}
