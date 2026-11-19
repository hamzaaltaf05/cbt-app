import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Clean, responsive Reddit-style Upvote/Downvote control widget.
///
/// Supports:
/// - Light & Dark modes via [Theme.of(context)]
/// - Responsive scaling via [MediaQuery]
/// - Flexible layout: Vertical (compact list tiles) or Horizontal (detail views)
/// - Instant optimistic feedback & haptic clicks
class VoteControlWidget extends StatelessWidget {
  const VoteControlWidget({
    super.key,
    required this.score,
    required this.userVote,
    required this.onVote,
    this.axis = Axis.vertical,
    this.compact = false,
  });

  /// Net score (upvotes - downvotes).
  final int score;

  /// Current user vote: 1 (upvoted), -1 (downvoted), 0 (none).
  final int userVote;

  /// Callback when user taps an arrow. Emits 1 (upvote) or -1 (downvote).
  final ValueChanged<int> onVote;

  /// Layout axis (vertical for compact cards, horizontal for detail screens).
  final Axis axis;

  /// Whether to use tight compact padding (e.g. for shop item tiles).
  final bool compact;

  static const Color upvoteColor = Color(0xFFFF4500); // Reddit orange-red
  static const Color downvoteColor = Color(0xFF5A75FF); // Reddit periwinkle blue

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSmallScreen = screenWidth < 360;

    final isUpvoted = userVote == 1;
    final isDownvoted = userVote == -1;

    final inactiveColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
        : theme.colorScheme.onSurface.withValues(alpha: 0.40);

    final scoreColor = isUpvoted
        ? upvoteColor
        : isDownvoted
            ? downvoteColor
            : theme.colorScheme.onSurface.withValues(alpha: 0.85);

    // Responsive icon and font sizes
    final double iconSize = compact || isSmallScreen ? 18.0 : 22.0;
    final double fontSize = compact || isSmallScreen ? 11.5 : 13.0;

    final containerBg = isDark
        ? (isUpvoted
            ? upvoteColor.withValues(alpha: 0.12)
            : isDownvoted
                ? downvoteColor.withValues(alpha: 0.12)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35))
        : (isUpvoted
            ? upvoteColor.withValues(alpha: 0.08)
            : isDownvoted
                ? downvoteColor.withValues(alpha: 0.08)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5));

    final border = isUpvoted
        ? Border.all(color: upvoteColor.withValues(alpha: 0.3), width: 1)
        : isDownvoted
            ? Border.all(color: downvoteColor.withValues(alpha: 0.3), width: 1)
            : Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25), width: 0.8);

    Widget buildUpButton() {
      return InkResponse(
        radius: iconSize + 4,
        onTap: () {
          HapticFeedback.selectionClick();
          onVote(1);
        },
        child: Padding(
          padding: EdgeInsets.all(compact ? 2.0 : 4.0),
          child: Icon(
            isUpvoted ? Icons.arrow_upward_rounded : Icons.arrow_upward_outlined,
            size: iconSize,
            color: isUpvoted ? upvoteColor : inactiveColor,
          ),
        ),
      );
    }

    Widget buildDownButton() {
      return InkResponse(
        radius: iconSize + 4,
        onTap: () {
          HapticFeedback.selectionClick();
          onVote(-1);
        },
        child: Padding(
          padding: EdgeInsets.all(compact ? 2.0 : 4.0),
          child: Icon(
            isDownvoted ? Icons.arrow_downward_rounded : Icons.arrow_downward_outlined,
            size: iconSize,
            color: isDownvoted ? downvoteColor : inactiveColor,
          ),
        ),
      );
    }

    Widget buildScoreText() {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Text(
          '$score',
          key: ValueKey<int>(score),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isUpvoted || isDownvoted ? FontWeight.bold : FontWeight.w600,
            color: scoreColor,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (axis == Axis.horizontal) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: containerBg,
          borderRadius: BorderRadius.circular(20),
          border: border,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildUpButton(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: buildScoreText(),
            ),
            buildDownButton(),
          ],
        ),
      );
    }

    // Default: Vertical axis (ideal for list item sidebars and shop items)
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 2 : 4,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(12),
        border: border,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildUpButton(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: buildScoreText(),
          ),
          buildDownButton(),
        ],
      ),
    );
  }
}
