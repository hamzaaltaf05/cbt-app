import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/auth/auth_cubit.dart';
import '../cubits/shop_feedback/shop_feedback_cubit.dart';
import '../cubits/shop_feedback/shop_feedback_state.dart';
import '../models/shop_feedback.dart';
import '../models/user_profile.dart';
import '../utils/relative_time.dart';
import '../widgets/vote_control_widget.dart';

/// Screen displaying public Honour Shop feedback & suggestions feed,
/// patterned after the Facility Issues screen.
class ShopFeedbackScreen extends StatelessWidget {
  const ShopFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ShopFeedbackCubit(),
      child: const _ShopFeedbackView(),
    );
  }
}

class _ShopFeedbackView extends StatelessWidget {
  const _ShopFeedbackView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<ShopFeedbackCubit>().state;
    final authCubit = context.watch<AuthCubit>();
    final canManageShop =
        authCubit.role == UserRole.admin || authCubit.role == UserRole.shopManager;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Shop Feedback & Suggestions'),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHeader(context),
          _buildFilterChips(context, state.filter),
          Expanded(
            child: state.isLoading && state.feedbacks.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.errorMessage != null && state.feedbacks.isEmpty
                    ? _buildErrorView(context, state.errorMessage!)
                    : state.filteredFeedbacks.isEmpty
                        ? _buildEmptyView(context, state.filter)
                        : RefreshIndicator(
                            onRefresh: () =>
                                context.read<ShopFeedbackCubit>().loadFeedback(),
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                              itemCount: state.filteredFeedbacks.length,
                              itemBuilder: (context, index) {
                                final post = state.filteredFeedbacks[index];
                                return _FeedbackCard(
                                  post: post,
                                  canRespond: canManageShop,
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainer
            : theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community Board',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Suggest new items or share feedback with managers.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () => _showCreatePostDialog(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Post'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, FeedbackFilter activeFilter) {
    final cubit = context.read<ShopFeedbackCubit>();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _buildChip(
            context: context,
            label: 'All Posts',
            isSelected: activeFilter == FeedbackFilter.all,
            onSelected: () => cubit.setFilter(FeedbackFilter.all),
          ),
          const SizedBox(width: 8),
          _buildChip(
            context: context,
            label: 'Suggestions',
            icon: Icons.lightbulb_outline,
            isSelected: activeFilter == FeedbackFilter.suggestions,
            onSelected: () => cubit.setFilter(FeedbackFilter.suggestions),
          ),
          const SizedBox(width: 8),
          _buildChip(
            context: context,
            label: 'Feedback',
            icon: Icons.rate_review_outlined,
            isSelected: activeFilter == FeedbackFilter.feedback,
            onSelected: () => cubit.setFilter(FeedbackFilter.feedback),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) => onSelected(),
      avatar: icon != null
          ? Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            )
          : null,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildEmptyView(BuildContext context, FeedbackFilter filter) {
    final label = switch (filter) {
      FeedbackFilter.suggestions => 'No suggestions yet.',
      FeedbackFilter.feedback => 'No feedback posts yet.',
      FeedbackFilter.all => 'No community posts yet.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Be the first to post a suggestion or feedback!',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _showCreatePostDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Post'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<ShopFeedbackCubit>().loadFeedback(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreatePostDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    FeedbackType selectedType = FeedbackType.suggestion;
    final cubit = context.read<ShopFeedbackCubit>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create Post',
                      style: Theme.of(dialogCtx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<FeedbackType>(
                      value: selectedType,
                      decoration: InputDecoration(
                        labelText: 'Post Type',
                        prefixIcon: Icon(selectedType.icon, color: selectedType.color),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: FeedbackType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Row(
                            children: [
                              Text(type.label),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: type.color.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  type.label,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: type.color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        hintText: selectedType == FeedbackType.suggestion
                            ? 'e.g. Add Sugar-Free Granola Bars'
                            : 'e.g. Coffee machine temperature issue',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: descController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Share more context or details...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final desc = descController.text.trim();
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(dialogCtx).showSnackBar(
                            const SnackBar(content: Text('Please enter a title')),
                          );
                          return;
                        }
                        if (desc.isEmpty) {
                          ScaffoldMessenger.of(dialogCtx).showSnackBar(
                            const SnackBar(content: Text('Please enter a description')),
                          );
                          return;
                        }

                        Navigator.pop(sheetContext);
                        final success = await cubit.createFeedback(
                          type: selectedType,
                          title: title,
                          description: desc,
                        );

                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${selectedType.label} posted successfully!',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      child: const Text('Submit Post'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Card representing a feedback/suggestion post with instant voting & admin response.
class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.post,
    required this.canRespond,
  });

  final ShopFeedback post;
  final bool canRespond;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Author & Type Badge
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: post.type.color.withValues(alpha: 0.15),
                  child: Icon(
                    post.type.icon,
                    size: 16,
                    color: post.type.color,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        relativeTime(post.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: post.type.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    post.type.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: post.type.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Title & Description
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              post.description,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.35,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 12),
            // Vote bar & Response trigger
            Row(
              children: [
                VoteControlWidget(
                  score: post.score,
                  userVote: post.userVote,
                  axis: Axis.horizontal,
                  compact: true,
                  onVote: (vote) =>
                      context.read<ShopFeedbackCubit>().castVote(post, vote),
                ),
                const Spacer(),
                if (canRespond)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _showResponseDialog(context, post),
                    icon: Icon(
                      post.isResponded ? Icons.edit_outlined : Icons.reply,
                      size: 16,
                    ),
                    label: Text(
                      post.isResponded ? 'Edit Reply' : 'Respond',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
              ],
            ),
            // Admin Response section
            if (post.isResponded) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
                      : const Color(0xFFF0FDF4), // Soft green tint
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? theme.colorScheme.outlineVariant.withValues(alpha: 0.3)
                        : Colors.green.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.verified,
                          size: 15,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Shop Manager Response',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? theme.colorScheme.onSurface
                                : Colors.green.shade900,
                          ),
                        ),
                        const Spacer(),
                        if (post.respondedAt != null)
                          Text(
                            relativeTime(post.respondedAt!),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? theme.colorScheme.onSurfaceVariant
                                  : Colors.green.shade700,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      post.adminResponse!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? theme.colorScheme.onSurface
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showResponseDialog(BuildContext context, ShopFeedback post) async {
    final controller = TextEditingController(text: post.adminResponse ?? '');
    final cubit = context.read<ShopFeedbackCubit>();

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(post.isResponded ? 'Edit Response' : 'Respond to Post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Responding as Admin/Shop Manager to "${post.title}".',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Official Response',
                  hintText: 'e.g. Thanks! We have ordered this item.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final responseText = controller.text.trim();
                if (responseText.isEmpty) return;

                Navigator.pop(dialogCtx);
                final success = await cubit.respondToFeedback(
                  feedbackId: post.id,
                  responseText: responseText,
                );

                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Response posted successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Post Response'),
            ),
          ],
        );
      },
    );
  }
}
