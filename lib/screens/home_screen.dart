import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../utils/responsive.dart';
import 'shop_items_screen.dart';
import 'facility_issues_screen.dart';
import 'user_management_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  bool _isAdmin = false;
  String _displayName = 'there';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// Loads the signed-in user's name and role from the `profiles` table,
  /// falling back to the email local-part until that resolves.
  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    var name = user?.email != null ? user!.email!.split('@').first : 'there';
    var role = UserRole.simpleUser;

    try {
      if (user != null) {
        final rows = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .limit(1)
            .maybeSingle();
        if (rows != null) {
          final profile = UserProfile.fromMap(rows);
          if (profile.fullName.isNotEmpty) name = profile.fullName;
          role = profile.role;
        }
      }
    } catch (_) {
      // Keep fallback name/role on failure.
    }

    if (mounted) {
      setState(() {
        _displayName = name;
        _isAdmin = role == UserRole.admin;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = _displayName.split(' ').first;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome back, $_displayName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.maxContentWidth(context),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.pagePadding(context),
                vertical: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What do you need today, $first?',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pick a service to get started.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    _buildTilesGrid(context, _isAdmin),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Responsive dashboard grid: a single row of wide tiles in landscape /
  /// wide screens, and a 2-column grid in narrow (portrait) screens.
  Widget _buildTilesGrid(BuildContext context, bool isAdmin) {
    final columns = Responsive.isLandscape(context) ? 4 : 2;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: columns,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildTile(
          Icons.storefront_outlined,
          'Honour Shop',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ShopItemsScreen()),
          ),
        ),
        _buildTile(
          Icons.report_problem_outlined,
          'Facility Issues',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FacilityIssuesScreen()),
          ),
        ),
        if (isAdmin)
          _buildTile(
            Icons.manage_accounts,
            'User Management',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserManagementScreen()),
            ),
          ),
      ],
    );
  }

  Widget _buildTile(IconData icon, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.primary, size: 30),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
