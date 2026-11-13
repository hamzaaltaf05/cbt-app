import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';

/// Central, observable source of truth for the signed-in user's in-app
/// notifications: the list, the unread badge count, and real-time delivery of
/// new notifications over the Supabase Realtime channel.
///
/// Exposed to the widget tree as a [ChangeNotifier] (via `Provider`), so the
/// tab-bar badge and the notification list both stay in sync.
class NotificationService extends ChangeNotifier {
  NotificationService(this._client) {
    refresh();
    _ensureRealtime();

    // Re-subscribe / refresh when a session becomes available, and clear when
    // the user signs out.
    _authSub = _client.auth.onAuthStateChange.listen((event) {
      if (_client.auth.currentSession != null) {
        _ensureRealtime();
        refresh();
      } else {
        _reset();
      }
    });
  }

  final SupabaseClient _client;

  List<AppNotification> _notifications = const [];
  bool _hasError = false;
  StreamSubscription<AuthState>? _authSub;
  RealtimeChannel? _channel;
  String? _subscribedUid;

  // ---------------------------------------------------------------- getters

  String? get userId => _client.auth.currentUser?.id;

  List<AppNotification> get notifications => _notifications;

  int get unreadCount =>
      _notifications.where((notification) => !notification.isRead).length;

  bool get hasError => _hasError;

  bool get isEmpty => _notifications.isEmpty;

  // ------------------------------------------------------------ mutations

  /// Loads the current user's notifications (most recent first).
  Future<void> refresh() async {
    final uid = userId;
    if (uid == null) return;

    try {
      final rows = await _client
          .from('notifications')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(100);

      final list = rows.map((row) => AppNotification.fromMap(row)).toList();

      _notifications = List.unmodifiable(list);
      _hasError = false;
      notifyListeners();
    } catch (error) {
      debugPrint('NotificationService.refresh failed: $error');
      _hasError = true;
      notifyListeners();
    }
  }

  /// Marks a single notification as read (optimistically) and persists it.
  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;

    _setNotifications(
      _notifications.map((existing) =>
          existing.id == notification.id ? _asRead(existing) : existing),
    );

    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notification.id);
    } catch (error) {
      debugPrint('NotificationService.markRead failed: $error');
    }
  }

  /// Marks every unread notification as read (optimistically) and persists.
  Future<void> markAllRead() async {
    final uid = userId;
    if (uid == null || unreadCount == 0) return;

    _setNotifications(
      _notifications.map((existing) => existing.isRead ? existing : _asRead(existing)),
    );

    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', uid)
          .eq('is_read', false);
    } catch (error) {
      debugPrint('NotificationService.markAllRead failed: $error');
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

  // ------------------------------------------------------------ realtime

  /// Opens (or reopens) the realtime channel for the current user, filtered to
  /// `user_id = auth.uid()`.
  void _ensureRealtime() {
    final uid = userId;
    if (uid == null || uid == _subscribedUid) return;

    final previous = _channel;
    _channel = null;
    _subscribedUid = uid;
    if (previous != null) {
      unawaited(_client.removeChannel(previous));
    }

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
        _insertRealtimeNotification(AppNotification.fromMap(payload.newRecord));
      },
    );
    channel.subscribe();
    _channel = channel;
  }

  void _insertRealtimeNotification(AppNotification notification) {
    final uid = userId;
    if (uid == null || notification.userId != uid) return;
    if (_notifications.any((existing) => existing.id == notification.id)) {
      return; // Already present (e.g. from a recent refresh).
    }
    _setNotifications([..._notifications, notification]);
  }

  void _setNotifications(Iterable<AppNotification> items) {
    _notifications = List.unmodifiable(items);
    _hasError = false;
    notifyListeners();
  }

  void _reset() {
    _notifications = const [];
    _hasError = false;
    final previous = _channel;
    _channel = null;
    _subscribedUid = null;
    notifyListeners();
    if (previous != null) {
      unawaited(_client.removeChannel(previous));
    }
  }

  @override
  Future<void> dispose() async {
    await _authSub?.cancel();
    final previous = _channel;
    _channel = null;
    if (previous != null) {
      await _client.removeChannel(previous);
    }
    super.dispose();
  }
}
