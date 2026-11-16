import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cbt_app/cubits/auth/auth_cubit.dart';
import 'package:cbt_app/cubits/auth/auth_state.dart';

import '../utils/responsive.dart';
import 'shop_items_screen.dart';
import 'facility_issues_screen.dart';
import 'user_management_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final profile = authState is AuthAuthenticated ? authState.profile : null;

    final displayName = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : (profile?.email.split('@').first ?? 'there');
    final isAdmin = profile?.isAdmin ?? false;
    final first = displayName.split(' ').first;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome back, $displayName'),
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
                  _buildTilesGrid(context, isAdmin, scheme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Responsive dashboard grid.
  Widget _buildTilesGrid(BuildContext context, bool isAdmin, ColorScheme scheme) {
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
          context,
          scheme,
          Icons.storefront_outlined,
          'Honour Shop',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ShopItemsScreen()),
          ),
        ),
        _buildTile(
          context,
          scheme,
          Icons.report_problem_outlined,
          'Facility Issues',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FacilityIssuesScreen()),
          ),
        ),
        if (isAdmin)
          _buildTile(
            context,
            scheme,
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

  Widget _buildTile(
    BuildContext context,
    ColorScheme scheme,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
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
