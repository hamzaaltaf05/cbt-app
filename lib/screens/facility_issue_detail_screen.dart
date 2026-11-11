import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/facility_issue.dart';
import '../utils/relative_time.dart';

/// Full detail view for a single facility issue.
class FacilityIssueDetailScreen extends StatelessWidget {
  const FacilityIssueDetailScreen({super.key, required this.issue});

  final FacilityIssue issue;

  static Future<void> show(BuildContext context, FacilityIssue issue) {
    return Navigator.push(context, MaterialPageRoute(builder: (_) => FacilityIssueDetailScreen(issue: issue)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Issue Details', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (issue.isDeletionRequested) ...[
            _DeletionRequestBanner(when: issue.deletionRequestedAt, onCancel: () => _cancelDeletionRequest(context)),
            const SizedBox(height: 12),
          ],
          _IssueCard(issue: issue),
          const SizedBox(height: 24),
          FutureBuilder<String>(
            future: _role(),
            builder: (context, snapshot) {
              final role = snapshot.data ?? '';
              final isAdmin = role == 'admin';
              final isOfficeAdmin = role == 'office_admin';
              final myUid = Supabase.instance.client.auth.currentUser?.id;
              final isReporter = myUid != null && myUid == issue.reportedBy;

              // Mirror the permissions already enforced by _confirmDelete / _showManageDialog,
              // so a user who cannot act on the issue never sees an action button for it.
              final canDelete = isReporter || isAdmin;
              final canManage = isAdmin;
              final canRequestDeletion = isOfficeAdmin && !isReporter && !issue.isDeletionRequested;
              final showManage = canManage || canRequestDeletion;

              // A plain "simple user" (not the reporter, not admin/office admin) can neither
              // delete nor manage this issue, so render no action row at all.
              if (!canDelete && !showManage) {
                return const SizedBox.shrink();
              }

              return Row(
                children: [
                  if (canDelete) ...[
                    Expanded(
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red, minimumSize: const Size.fromHeight(48)),
                        onPressed: () => _confirmDelete(context),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.delete_outline, size: 20),
                          SizedBox(width: 8),
                          Flexible(child: Text('Delete this issue', overflow: TextOverflow.ellipsis, maxLines: 1, style: TextStyle(fontWeight: FontWeight.w600))),
                        ]),
                      ),
                    ),
                    if (showManage) const SizedBox(width: 12),
                  ],
                  if (showManage)
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
                        onPressed: () => _showManageDialog(context),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        label: const Text('Manage', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
  Future<void> _showManageDialog(BuildContext context) async {
    final client = Supabase.instance.client;
    final myUid = client.auth.currentUser?.id;
    final isReporter = myUid == issue.reportedBy;
    final role = await _role();
    if (!context.mounted) return;
    final isAdmin = role == 'admin';
    final isOfficeAdmin = role == 'office_admin';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _ManageIssueDialog(
        status: issue.status,
        response: issue.adminResponse,
        canManage: isAdmin,
        canRequestDeletion: isOfficeAdmin && !isReporter && !issue.isDeletionRequested,
      ),
    );
    if (result == null) return;
    if (!context.mounted) return;

    if (result.containsKey('delete_requested')) {
      await _requestDeletion(context, client);
      return;
    }
    final status = result['status'];
    final response = result['response'];
    if (status == null && response == null) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final updates = <String, String>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (status != null) updates['status'] = status;
      if (response != null) updates['admin_response'] = response;
      await client.from('facility_issues').update(updates).eq('id', issue.id);
      messenger.showSnackBar(SnackBar(content: const Text('Issue updated'), backgroundColor: Colors.green));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<String> _role() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return '';
    final rows = await client.from('profiles').select('role').eq('id', uid).limit(1);
    return (rows.firstOrNull?['role'] as String?) ?? '';
  }

  Future<void> _requestDeletion(BuildContext context, SupabaseClient client) async {
    try {
      await client.rpc('request_issue_deletion', params: {'issue_id': issue.id});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deletion request sent to the reporter'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send request: $e')));
      }
    }
  }
  Future<void> _cancelDeletionRequest(BuildContext context) async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel deletion request?'),
        content: const Text('This removes the deletion request and keeps the issue visible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep request')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel request')),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    try {
      await client.rpc('cancel_issue_deletion_request', params: {'issue_id': issue.id, 'requester_id': uid});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deletion request cancelled'), backgroundColor: Colors.blueGrey));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not cancel: $e')));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final client = Supabase.instance.client;
    final myUid = client.auth.currentUser?.id;
    if (myUid == null) return;

    final isReporter = myUid == issue.reportedBy;
    final role = await _role();
    if (!context.mounted) return;
    if (!isReporter && role != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only the reporter or an admin can delete this issue.')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this issue?'),
        content: Text('"${issue.title}" will be permanently removed. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await client.from('facility_issues').delete().eq('id', issue.id);
      // The row (and its pending deletion request, if any) is removed above;
      // no separate cleanup RPC is needed — calling one here would 404.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Issue deleted'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }
}

class _DeletionRequestBanner extends StatelessWidget {
  const _DeletionRequestBanner({required this.when, required this.onCancel});

  final DateTime? when;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade300)),
      child: Row(
        children: [
          Icon(Icons.gavel_rounded, color: Colors.orange.shade700, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Deletion requested', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                const SizedBox(height: 2),
                Text(
                  when == null ? 'An office admin has asked you to delete this issue.' : 'Requested ${relativeTime(when!)}. Please delete this issue.',
                  style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onCancel, child: const Text('Dismiss request')),
        ],
      ),
    );
  }
}
class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.issue});

  final FacilityIssue issue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (issue.imageUrl != null && issue.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                issue.imageUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(height: 120, color: Colors.grey.shade100, child: const Icon(Icons.broken_image, color: Colors.grey)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(issue.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: issue.statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                      child: Text(issue.statusLabel, style: TextStyle(color: issue.statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Resolve the reporter's display name (profiles.full_name) instead of
                // showing the raw user id. Falls back to the id if the lookup fails or
                // the name is empty, so the line is never blank.
                Container(
                  alignment: Alignment.centerLeft,
                  child: FutureBuilder<String>(
                    future: () async {
                      final client = Supabase.instance.client;
                      final rows = await client.from('profiles').select('full_name').eq('id', issue.reportedBy).limit(1);
                      final row = rows.firstOrNull;
                      final fullName = (row?['full_name'] as String?)?.trim() ?? '';
                      return fullName.isNotEmpty ? fullName : issue.reportedBy;
                    }(),
                    builder: (context, snapshot) {
                      final reporter = snapshot.data ?? issue.reportedBy;
                      return Text('$reporter  ·  ${relativeTime(issue.createdAt)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12));
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Text(issue.description, style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87)),
                if (issue.adminResponse != null && issue.adminResponse!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Admin Response', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB))),
                        const SizedBox(height: 6),
                        Text(issue.adminResponse!, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ],
                if (issue.updatedAt != null) ...[
                  const SizedBox(height: 14),
                  Text('Last updated ${relativeTime(issue.updatedAt!)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _ManageIssueDialog extends StatefulWidget {
  const _ManageIssueDialog({required this.status, required this.response, required this.canManage, required this.canRequestDeletion});

  final IssueStatus status;
  final String? response;
  final bool canManage;
  final bool canRequestDeletion;

  @override
  State<_ManageIssueDialog> createState() => _ManageIssueDialogState();
}

class _ManageIssueDialogState extends State<_ManageIssueDialog> {
  late IssueStatus _selected;
  late TextEditingController _responseController;

  @override
  void initState() {
    super.initState();
    _selected = widget.status;
    _responseController = TextEditingController(text: widget.response ?? '');
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Issue'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.canManage) ...[
            DropdownButtonFormField<IssueStatus>(
              initialValue: _selected,
              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
              items: IssueStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))).toList(),
              onChanged: (v) => setState(() => _selected = v ?? IssueStatus.pending),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _responseController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Admin Response', hintText: 'Add a note or response…', border: OutlineInputBorder()),
            ),
          ] else if (widget.canRequestDeletion) ...[
            Text('As an office admin you cannot delete issues directly. You can request the reporter to delete this issue.', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ] else ...[
            Text('You do not have permission to manage this issue.', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        if (widget.canRequestDeletion)
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(context, {'delete_requested': 'true'}),
            icon: const Icon(Icons.gavel_outlined),
            label: const Text('Request Deletion'),
          ),
        if (widget.canManage)
          FilledButton(
            onPressed: () => Navigator.pop(context, {'status': _selected.dbValue, 'response': _responseController.text.trim()}),
            child: const Text('Save Changes'),
          ),
      ],
    );
  }
}