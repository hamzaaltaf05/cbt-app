import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import '../models/facility_issue.dart';
import '../screens/facility_issue_detail_screen.dart';
import '../services/notification_service.dart';

/// The "Notifications" tab.
///
/// A live feed of every notification addressed to the signed-in user. New
/// items stream in over Supabase Realtime, keeping the list in sync without
/// any manual refreshes.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  NotificationService? _service;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service?.removeListener(_onServiceChanged);
    _service?.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    setState(() {
      _error = _service?.hasError == true
          ? 'Failed to load notifications.'
          : null;
    });
  }

  Future<void> _load() async {
    final service = NotificationService(Supabase.instance.client);
    _service = service;
    service.addListener(_onServiceChanged);
    setState(() => _loading = true);
    await service.refresh();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markRead(AppNotification n) async {
    await _service?.markRead(n);
  }

  Future<void> _markAllRead() async {
    if (_service?.unreadCount != 0) return;
    await _service?.markAllRead();
  }

  Future<void> _refreshList() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _service?.refresh();
    if (mounted) setState(() => _loading = false);
  }

  /// Tapping a facility-issue notification opens the existing, full-featured
  /// [FacilityIssueDetailScreen] for that issue (which supports managing,
  /// responding to, and deleting the issue).
  Future<void> _openFacilityDetail(
      BuildContext context, AppNotification notification) async {
    final refId = notification.refId;
    if (refId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This issue is no longer available.')),
        );
      }
      return;
    }
    try {
      final List<Map<String, dynamic>> rows =
          await Supabase.instance.client
              .from('facility_issues')
              .select('*')
              .eq('id', refId)
              .order('created_at', ascending: false);
      final row = rows.isNotEmpty ? rows.first : null;
      if (!context.mounted) return;
      if (row == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This issue is no longer available.')),
        );
        return;
      }
      final issue = FacilityIssue.fromMap(row);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FacilityIssueDetailScreen(issue: issue),
        ),
      );
    } catch (error) {
      debugPrint('NotificationScreen._openFacilityDetail failed: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the issue details.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = _service;
    final items = service?.notifications ?? const <AppNotification>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (service != null && service.unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.mark_chat_read),
              tooltip: 'Mark all as read',
              onPressed: _markAllRead,
            ),
        ],
      ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              onPressed: _refreshList,
            ),
      body: _buildBody(context, items),
    );
  }

  Widget _buildBody(BuildContext context, List<AppNotification> items) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _refreshList,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (items.isEmpty) {
      return _buildEmpty(context);
    }
    return RefreshIndicator(
      onRefresh: _refreshList,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, index) => _buildItem(context, items[index]),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none,
              size: 72,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'You’re all caught up',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'New updates from your facility will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, AppNotification n) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      color: n.isRead
          ? null
          : colorScheme.primaryContainer.withValues(alpha: 0.4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: n.isRead
              ? Colors.transparent
              : colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _markRead(n);
          if (n.isFacility) {
            _openFacilityDetail(context, n);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    n.isFacility
                        ? Icons.construction
                        : Icons.notifications_active,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                n.isRead ? FontWeight.w400 : FontWeight.w600,
                            color: n.isRead
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.onSurface,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (n.body != null && n.body!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              n.body!,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!n.isRead)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 8),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _relativeTime(n.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return time.toLocal().toString().substring(0, 10);
  }
}
