import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cbt_app/models/user_profile.dart';
import 'package:cbt_app/screens/facility_issues_screen.dart';
import 'package:cbt_app/screens/shop_items_screen.dart';
import 'package:cbt_app/screens/user_management_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserRole? _userRole;
  String _fullName = 'User';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      _fullName =
          Supabase.instance.client.auth.currentUser?.userMetadata?['full_name']
              as String? ??
          'User';
      if (uid == null) {
        _userRole = UserRole.simpleUser;
        _isLoading = false;
        return;
      }
      final row = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', uid)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;

      if (row == null) {
        // No profile row exists (e.g. the account predates the
        // handle_new_user trigger) — recreate it as a plain employee
        // instead of silently falling back to Simple User.
        await Supabase.instance.client.from('profiles').upsert({
          'id': uid,
          'full_name':
              Supabase
                      .instance
                      .client
                      .auth
                      .currentUser
                      ?.userMetadata?['full_name']
                  as String? ??
              'User',
          'role': 'employee',
        });

        final recreated = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', uid)
            .limit(1)
            .maybeSingle();

        if (!mounted) return;

        setState(() {
          _userRole = recreated != null
              ? UserProfile.fromMap(recreated).role
              : UserRole.simpleUser;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _userRole = UserProfile.fromMap(row).role;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userRole = UserRole.simpleUser;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Supabase.instance.client.auth.currentUser == null) {
      return const Scaffold();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Convergent'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Supabase.instance.client.auth.signOut(),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    child: Text(
                      _fullName.isNotEmpty ? _fullName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 36,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _fullName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _roleBadge(),
                  const SizedBox(height: 36),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: [
                        _buildNavCard(
                          icon: Icons.storefront,
                          title: 'Shop Items',
                          subtitle: 'Browse & manage shop inventory',
                          color: Theme.of(context).colorScheme.primary,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ShopItemsScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildNavCard(
                          icon: Icons.report_problem,
                          title: 'Facility Issues',
                          subtitle: 'Report & track facility issues',
                          color: Colors.teal.shade700,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FacilityIssuesScreen(),
                            ),
                          ),
                        ),
                        if (_userRole == UserRole.admin) ...[
                          const SizedBox(height: 14),
                          _buildNavCard(
                            icon: Icons.manage_accounts,
                            title: 'User Management',
                            subtitle: 'Assign roles to users',
                            color: Colors.deepPurple,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const UserManagementScreen(),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _roleBadge() {
    final color = _userRole == UserRole.admin
        ? Colors.red
        : _userRole == UserRole.shopManager
        ? Colors.orange.shade700
        : Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _userRole?.displayName ?? 'User',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildNavCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withAlpha(40)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 30, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
