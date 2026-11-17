import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cubits/auth/auth_cubit.dart';
import '../cubits/facility_issues/facility_issues_cubit.dart';
import '../models/facility_issue.dart';
import '../utils/relative_time.dart';

/// Full detail view for a single facility issue.
class FacilityIssueDetailScreen extends StatelessWidget {
  const FacilityIssueDetailScreen({super.key, required this.issue});

  final FacilityIssue issue;

  static Future<void> show(BuildContext context, FacilityIssue issue) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FacilityIssueDetailScreen(issue: issue),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final issues = context.watch<FacilityIssuesCubit>().state.issues;
    final currentIssue =
        issues.firstWhere((i) => i.id == issue.id, orElse: () => issue);

    final authCubit = context.watch<AuthCubit>();
    final isAdmin = authCubit.isAdmin;
    final isOfficeAdmin = authCubit.isOfficeAdmin;
    final myUid = authCubit.profile?.id ??
        Supabase.instance.client.auth.currentUser?.id;
    final isReporter = myUid != null && myUid == currentIssue.reportedBy;

    final canDelete = isReporter || isAdmin;
    final canManage = isAdmin || isOfficeAdmin;
    final canRequestDeletion =
        isOfficeAdmin && !isReporter && !currentIssue.isDeletionRequested;
    final showManage = canManage || canRequestDeletion;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Issue Details',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (currentIssue.isDeletionRequested) ...[
            _DeletionRequestBanner(
              when: currentIssue.deletionRequestedAt,
              onCancel: () => _cancelDeletionRequest(context, currentIssue),
            ),
            const SizedBox(height: 12),
          ],
          _IssueCard(issue: currentIssue),
          const SizedBox(height: 24),
          if (canDelete || showManage)
            Row(
              children: [
                if (canDelete) ...[
                  Expanded(
                    flex: showManage ? 3 : 1,
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => _confirmDelete(context, currentIssue),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline, size: 19),
                          SizedBox(width: 6),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Delete Issue',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (showManage) const SizedBox(width: 10),
                ],
                if (showManage)
                  Expanded(
                    flex: canDelete ? 2 : 1,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => _showManageDialog(
                        context,
                        currentIssue,
                        canManage: canManage,
                        canRequestDeletion: canRequestDeletion,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 19),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Manage',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _showManageDialog(
    BuildContext context,
    FacilityIssue targetIssue, {
    required bool canManage,
    required bool canRequestDeletion,
  }) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _ManageIssueDialog(
        status: targetIssue.status,
        response: targetIssue.adminResponse,
        canManage: canManage,
        canRequestDeletion: canRequestDeletion,
      ),
    );
    if (result == null) return;
    if (!context.mounted) return;

    if (result.containsKey('delete_requested')) {
      await _requestDeletion(context, targetIssue);
      return;
    }
    final statusStr = result['status'];
    final response = result['response'];
    if (statusStr == null && response == null) return;

    final newStatus =
        statusStr != null ? IssueStatus.fromValue(statusStr) : targetIssue.status;

    // 1. Immediately trigger optimistic update in Cubit (0ms delay)
    context.read<FacilityIssuesCubit>().updateIssue(
          id: targetIssue.id,
          status: newStatus,
          adminResponse: response,
        );

    // 2. Take the user outside the issue details back to the list
    Navigator.of(context).pop();

    // 3. Show confirmation feedback on the issues screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Issue updated successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _requestDeletion(
    BuildContext context,
    FacilityIssue targetIssue,
  ) async {
    final success = await context
        .read<FacilityIssuesCubit>()
        .requestDeletion(targetIssue.id);

    if (context.mounted) {
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deletion request sent to the reporter'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not send deletion request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelDeletionRequest(
    BuildContext context,
    FacilityIssue targetIssue,
  ) async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel deletion request?'),
        content: const Text(
          'This removes the deletion request and keeps the issue visible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep request'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    try {
      await client.rpc(
        'cancel_issue_deletion_request',
        params: {'issue_id': targetIssue.id, 'requester_id': uid},
      );
      if (context.mounted) {
        context.read<FacilityIssuesCubit>().loadIssues();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deletion request cancelled'),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not cancel: $e')));
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    FacilityIssue targetIssue,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this issue?'),
        content: Text(
          '"${targetIssue.title}" will be permanently removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final success =
        await context.read<FacilityIssuesCubit>().deleteIssue(targetIssue.id);

    if (context.mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Issue deleted'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete issue'),
            backgroundColor: Colors.red,
          ),
        );
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
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.gavel_rounded, color: Colors.orange.shade700, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Deletion requested',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orangeAccent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  when == null
                      ? 'An office admin has asked you to delete this issue.'
                      : 'Requested ${relativeTime(when!)}. Please delete this issue.',
                  style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: onCancel,
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Dismiss'),
            ),
          ),
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
    final hasImage = issue.imageUrl != null && issue.imageUrl!.isNotEmpty;
    final heroTag = 'issue_image_${issue.id}';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenImageViewer(
                      imageUrl: issue.imageUrl!,
                      title: issue.title,
                      heroTag: heroTag,
                    ),
                  ),
                );
              },
              child: Stack(
                children: [
                  Hero(
                    tag: heroTag,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: Image.network(
                        issue.imageUrl!,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: 120,
                          color: Colors.grey.shade100,
                          child:
                              const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_in, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Tap to zoom',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        issue.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (issue.isPrivate) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 12,
                              color: Colors.purple,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Private',
                              style: TextStyle(
                                color: Colors.purple,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: issue.statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        issue.statusLabel,
                        style: TextStyle(
                          color: issue.statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  alignment: Alignment.centerLeft,
                  child: FutureBuilder<String>(
                    future: () async {
                      final cached = context
                          .read<FacilityIssuesCubit>()
                          .state
                          .reporterNames[issue.reportedBy];
                      if (cached != null && cached.isNotEmpty) return cached;

                      final client = Supabase.instance.client;
                      final rows = await client
                          .from('profiles')
                          .select('full_name')
                          .eq('id', issue.reportedBy)
                          .limit(1);
                      final row = rows.firstOrNull;
                      final fullName =
                          (row?['full_name'] as String?)?.trim() ?? '';
                      return fullName.isNotEmpty ? fullName : issue.reportedBy;
                    }(),
                    builder: (context, snapshot) {
                      final reporter = snapshot.data ?? issue.reportedBy;
                      return Text(
                        '$reporter  ·  ${relativeTime(issue.createdAt)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  issue.description,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (issue.adminResponse != null &&
                    issue.adminResponse!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Admin Response',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          issue.adminResponse!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (issue.updatedAt != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Last updated ${relativeTime(issue.updatedAt!)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A full-screen interactive image viewer supporting pinch-to-zoom,
/// double-tap zoom, and panning.
class FullScreenImageViewer extends StatelessWidget {
  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    this.title,
  });

  final String imageUrl;
  final String heroTag;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final TransformationController transformationController =
        TransformationController();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        foregroundColor: Colors.white,
        title: title != null
            ? Text(
                title!,
                style: const TextStyle(fontSize: 16, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt, color: Colors.white),
            tooltip: 'Reset zoom',
            onPressed: () {
              transformationController.value = Matrix4.identity();
            },
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            transformationController: transformationController,
            minScale: 0.5,
            maxScale: 5.0,
            clipBehavior: Clip.none,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                    color: Colors.white,
                  ),
                );
              },
              errorBuilder: (_, __, ___) => const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image, size: 56, color: Colors.white54),
                    SizedBox(height: 12),
                    Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ManageIssueDialog extends StatefulWidget {
  const _ManageIssueDialog({
    required this.status,
    required this.response,
    required this.canManage,
    required this.canRequestDeletion,
  });

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
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: IssueStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selected = v ?? IssueStatus.pending),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _responseController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Admin Response',
                hintText: 'Add a note or response…',
                border: OutlineInputBorder(),
              ),
            ),
          ] else if (widget.canRequestDeletion) ...[
            Text(
              'As an office admin you cannot delete issues directly. You can request the reporter to delete this issue.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            Text(
              'You do not have permission to manage this issue.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (widget.canManage)
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'status': _selected.dbValue,
              'response': _responseController.text.trim(),
            }),
            child: const Text('Save Changes'),
          ),
      ],
    );
  }
}
