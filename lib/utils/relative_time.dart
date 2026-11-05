// Lightweight relative-time formatting for the facility-issues screens.
//
// No external packages (no `timeago` / `intl`); callers drive a single
// ~30-second `Timer.periodic` and re-render so the strings stay fresh.

/// Human-friendly relative time, e.g. "just now", "5 min ago", "2 hr ago".
String relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  final seconds = diff.inSeconds;
  if (seconds < 45) return 'just now';
  final minutes = diff.inMinutes;
  if (minutes < 60) return '$minutes min ago';
  final hours = diff.inHours;
  if (hours < 24) return '$hours hr ago';
  final days = diff.inDays;
  if (days < 7) return '$days day ago';
  final weeks = days ~/ 7;
  if (weeks < 4) return '$weeks wk ago';
  final months = days ~/ 30;
  if (months < 12) return '$months mo ago';
  return '${days ~/ 365} yr ago';
}

/// Full, unambiguous timestamp for the detail screen,
/// e.g. "11 Nov 2026, 14:32:05".
String fullTimestamp(DateTime time) {
  final t = time.toLocal();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${_two(t.day)} ${months[t.month - 1]} ${t.year}, '
      '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
}

String _two(int v) => v.toString().padLeft(2, '0');
