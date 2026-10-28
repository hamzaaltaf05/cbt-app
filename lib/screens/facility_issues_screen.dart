import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cbt_app/models/facility_issue.dart';
import 'package:cbt_app/models/user_profile.dart';

class FacilityIssuesScreen extends StatefulWidget {
  const FacilityIssuesScreen({super.key});

  @override
  State<FacilityIssuesScreen> createState() => _FacilityIssuesScreenState();
}

class _FacilityIssuesScreenState extends State<FacilityIssuesScreen> {
  List<FacilityIssue> _issues = [];
  Map<String, String> _reporterNames = {};
  bool _isLoading = true;
  String? _error;
  UserRole? _userRole;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  bool get _isAdmin => _userRole == UserRole.admin;

  Future<void> _loadData() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final profileRows = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', uid)
          .limit(1)
          .maybeSingle();
      _userRole = profileRows != null
          ? UserProfile.fromMap(profileRows).role
          : UserRole.simpleUser;
      await _loadIssues();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load data: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadIssues() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final rows = await Supabase.instance.client
          .from('facility_issues')
          .select('*, profiles!facility_issues_reported_by_key(full_name)')
          .order('created_at', ascending: false)
          ;
      _issues = rows.map((row) => FacilityIssue.fromMap(row)).toList();
      _reporterNames = {};
      for (var row in rows) {
        final issue = FacilityIssue.fromMap(row);
        final profile = row['profiles'] as Map<String, dynamic>?;
        if (profile != null) {
          _reporterNames[issue.reportedBy] =
              profile['full_name'] as String? ?? 'Unknown';
        }
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load issues: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showCreateDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Facility Issue'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Broken AC in Room 204',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Describe the issue in detail...',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isEmpty ||
                  descController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please fill all fields')));
                return;
              }
              Navigator.pop(context);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    final title = titleController.text.trim();
    final desc = descController.text.trim();
    if (title.isEmpty || desc.isEmpty) return;

    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client
          .from('facility_issues')
          .insert({
            'title': title,
            'description': desc,
            'reported_by': uid,
            'status': 'pending',
          })
          ;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Issue submitted successfully'),
            backgroundColor: Colors.green));
      }
      _loadIssues();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

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
          ;

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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withAlpha(15),
                    blurRadius: 20,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Facility Issues',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          _isAdmin
                              ? 'View and manage all reports'
                              : 'View all reports',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () => _showCreateDialog(),
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 18),
                          SizedBox(width: 6),
                          Text('Report',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 48, color: Colors.red.shade300),
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                  onPressed: _loadIssues,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Try Again')),
                            ]),
                      )
                    : _issues.isEmpty
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.description_outlined,
                                      size: 56, color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No issues reported yet',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tap "Report" to be the first!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade400),
                                  ),
                                ]),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadIssues,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.only(top: 8, bottom: 80),
                              children: _issues.map(_buildIssueTile).toList(),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}