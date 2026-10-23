import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cbt_app/models/user_profile.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<UserProfile> _users = [];
  bool _isLoading = true;
  String? _error;
  final String _currentUid = Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rows = await Supabase.instance.client
          .from('profiles')
          .select()
          .order('full_name', ascending: true)
          ;

      if (mounted) {
        setState(() {
          _users = rows.map((row) => UserProfile.fromMap(row)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load users: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _changeRole(UserProfile user, UserRole newRole) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'role': newRole.label})
          .eq('id', user.id)
          ;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${user.fullName} is now ${newRole.displayName}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.shopManager:
        return Colors.orange;
      case UserRole.simpleUser:
        return Colors.blueGrey;
    }
  }

  Widget _buildUserTile(UserProfile user) {
    final isSelf = user.id == _currentUid;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _roleColor(user.role),
              child: Text(
                user.fullName.isNotEmpty
                    ? user.fullName[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName.isEmpty ? 'Unknown' : user.fullName,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _roleColor(user.role).withAlpha(40),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          user.role.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            color: _roleColor(user.role).withAlpha(200),
                          ),
                        ),
                      ),
                      if (isSelf) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('You',
                              style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            DropdownButton<UserRole>(
              value: user.role,
              underline: Container(),
              items: const [
                DropdownMenuItem(
                  value: UserRole.admin,
                  child: Text('Admin'),
                ),
                DropdownMenuItem(
                  value: UserRole.shopManager,
                  child: Text('Shop Manager'),
                ),
                DropdownMenuItem(
                  value: UserRole.simpleUser,
                  child: Text('Simple User'),
                ),
              ],
              onChanged: isSelf
                  ? null
                  : (newRole) {
                      if (newRole != null && newRole != user.role) {
                        _changeRole(user, newRole);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
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
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                            onPressed: _loadUsers, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: _users.map(_buildUserTile).toList(),
                  ),
                ),
    );
  }
}