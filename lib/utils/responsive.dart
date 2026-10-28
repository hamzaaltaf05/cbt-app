import 'package:flutter/material.dart';

/// Lightweight, dependency-free responsive helpers built on top of
/// [MediaQuery].
///
/// Screens read their layout decisions from here instead of comparing raw
/// pixel values themselves, so breakpoints stay consistent across the app.
class Responsive {
  Responsive._();

  /// Current available width (logical px).
  static double width(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  /// Current available height (logical px).
  static double height(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  /// True when the layout is wider than it is tall.
  static bool isLandscape(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return size.width > size.height - bottomInset;
  }

  /// True on small phones (roughly < 600 logical px).
  static bool isPhone(BuildContext context) => width(context) < 600;

  /// True on tablets and larger (>= 840 logical px).
  static bool isTablet(BuildContext context) => width(context) >= 840;

  /// Upper bound for single-column content (login card, home dashboard) so it
  /// does not stretch edge-to-edge on large screens.
  static double maxContentWidth(BuildContext context) =>
      width(context) >= 1200 ? 860 : width(context);

  /// Horizontal page padding that grows on larger screens.
  static double pagePadding(BuildContext context) {
    if (isTablet(context)) return 32;
    if (width(context) >= 600) return 24;
    return 16;
  }
}