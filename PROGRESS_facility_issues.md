# Progress: Facility Issues Screen (facility_issues_screen.dart)

## Goal
Build a complete `FacilityIssuesScreen` Flutter screen in
`c:\Users\HamzaAltaf\StudioProjects\cbt_app\lib\screens\facility_issues_screen.dart`.

- Any user can **report** a facility issue (title + description) via a FAB dialog.
- All users can **view** the list of issues (newest first) with reporter name,
  date, status badge, and admin response (if any).
- **Admins only** can tap an issue to open a management dialog to change status
  (pending / in_progress / resolved / rejected) and add an admin response.

## Key dependencies (already exist — do NOT recreate)
- `package:supabase_flutter/supabase_flutter.dart` (Supabase)
- `lib/models/facility_issue.dart` → `FacilityIssue` model, `FacilityIssue.fromMap(row)`,
  fields: `id`, `title`, `description`, `reportedBy`, `status`, `adminResponse`, `createdAt`.
  Also `IssueStatus` enum: `pending`, `inProgress`, `resolved`, `rejected`.
- `lib/models/user_profile.dart` → `UserProfile.fromMap(row)`, `.role` → `UserRole`
  enum with `UserRole.admin`, `UserRole.simpleUser`.

DB table: `facility_issues` with columns `id`, `title`, `description`, `reported_by`,
`status` (text: 'pending'|'in_progress'|'resolved'|'rejected'), `admin_response`,
`created_at`. Foreign key `reported_by` → `profiles(id)`; join for `full_name`.

> NOTE: DB status is stored as text (`in_progress`). `IssueStatus` enum uses `inProgress`.
> Use helper `_statusToDbValue(IssueStatus)` to map `IssueStatus.inProgress` -> `'in_progress'`,
> else `status.name`.

## Status of the file
The file EXISTS and currently has **162 lines**. Lines 1-162 already contain (and are correct):
- imports, `class FacilityIssuesScreen`, `_FacilityIssuesScreenState` with fields
  `_issues`, `_reporterNames`, `_isLoading`, `_error`, `_userRole`
- `initState`, `_isAdmin` getter
- `_loadData()`, `_loadIssues()`, and `_showCreateDialog()` (which ends at line 162)

## WHAT IS LEFT TO DO
Append the remaining methods **after line 162**, INSIDE the
`_FacilityIssuesScreenState` class (before the class's final closing brace `}`).
If the file currently ends with a single top-level `}` (class already closed),
remove that `}`, paste the remaining methods, then re-add the final `}`.
The remaining code is in the three parts below — paste Part A, B, and C in order,
then ensure the file ends with exactly ONE top-level `}`.

### PART A — append this (starts with a blank line, then the method):

```dart

  Future<void> _showAdminDialog(FacilityIssue issue) async {
    final responseController =
        TextEditingController(text: issue.adminResponse ?? '');
    String selectedStatus = _statusToDbValue(issue.status);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(issue.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Description',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(issue.description,
                    style: const TextStyle(fontSize: 14, height: 1.4)),
                const SizedBox(height: 20),
                Text('Status',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: selectedStatus,
                    underline: Container(),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                          value: 'pending', child: Text('⏳ Pending')),
                      DropdownMenuItem(
                          value: 'in_progress', child: Text('🔧 In Progress')),
                      DropdownMenuItem(
                          value: 'resolved', child: Text('✅ Resolved')),
                      DropdownMenuItem(
                          value: 'rejected', child: Text('❌ Rejected')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedStatus = value);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Text('Admin Response',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: responseController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Add a response or note...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    try {
      await Supabase.instance.client
          .from('facility_issues')
          .update({
            'status': selectedStatus,
            'admin_response': responseController.text.trim().isEmpty
                ? null
                : responseController.text.trim(),
          })
          .eq('id', issue.id)
          .execute();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Issue updated successfully'),
              backgroundColor: Colors.green),
        );
      }
      _loadIssues();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  String _statusToDbValue(IssueStatus status) {
    switch (status) {
      case IssueStatus.inProgress:
        return 'in_progress';
      default:
        return status.name;
    }
  }

  Color _statusColor(IssueStatus status) {
    switch (status) {
      case IssueStatus.pending:
        return Colors.orange;
      case IssueStatus.inProgress:
        return Colors.blue;
      case IssueStatus.resolved:
        return Colors.green;
      case IssueStatus.rejected:
        return Colors.red;
    }
  }

  String _statusLabel(IssueStatus status) {
    switch (status) {
      case IssueStatus.pending:
        return 'Pending';
      case IssueStatus.inProgress:
        return 'In Progress';
      case IssueStatus.resolved:
        return 'Resolved';
      case IssueStatus.rejected:
        return 'Rejected';
    }
  }

  String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  Widget _buildIssueTile(FacilityIssue issue) {
    final reporterName = _reporterNames[issue.reportedBy] ?? 'Unknown';
    final statusColor = _statusColor(issue.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: statusColor.withAlpha(60))),
      child: InkWell(
        onTap: _isAdmin ? () => _showAdminDialog(issue) : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      issue.title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(40),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      _statusLabel(issue.status),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                issue.description,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (issue.adminResponse != null &&
                  issue.adminResponse!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.admin_panel_settings,
                          size: 14, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          issue.adminResponse!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.blueGrey),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    reporterName,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(width: 14),
                  Icon(Icons.schedule,
                      size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(issue.createdAt),
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  if (_isAdmin) ...[
                    const Spacer(),
                    Text(
                      'Tap to manage ›',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade400,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Facility Issues'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add_comment, color: Colors.white),
        label: const Text('Report Issue',
            style: TextStyle(color: Colors.white, fontSize: 14)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _issues.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.report_outlined,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'No facility issues reported yet.',
                            style:
                                TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Use the button below to report an issue.',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadIssues,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 8, bottom: 80),
                        children: _issues.map(_buildIssueTile).toList(),
                      ),
                    ),
    );
  }
}

---

## Resolution Log (updated after compilation errors)

### Root cause

- `postgrest` 2.9.1 (used by `supabase_flutter` 2.18.0) has **no public `execute()`** method. The query builder itself implements `Future`, so the correct pattern is to directly `await` the query chain (or use `.then(...)`).

### Fixes applied

1. `lib/screens/facility_issues_screen.dart` — removed `.execute()` (3 places: `_loadIssues`, `_showCreateDialog`, `_showAdminDialog`); now `await Supabase.instance.client.from(...)...` directly.
2. `lib/screens/shop_items_screen.dart` — removed `.execute()` (3 places).
3. `lib/screens/user_management_screen.dart` — removed `.execute()` (2 places).
4. `lib/screens/home_screen.dart` — added null guard for `uid` before `.eq('id', uid)` (`String?` cannot be passed where `Object` is required).
5. `lib/models/facility_issue.dart` — removed unused `supabase_flutter` import (warning).

### Verification

- `flutter analyze` — **0 errors, 0 warnings** (only pre-existing info lints remain: deprecated `anonymKey` in `main.dart:13`, `curly_braces_in_flow_control_structures` in `home_screen.dart:59`, and 4 `use_build_context_synchronously` infos in `shop_items_screen`/`user_management_screen`).

