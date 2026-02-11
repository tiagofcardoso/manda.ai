import 'package:flutter/material.dart';

/// Responsive breakpoint helper for adaptive layouts
class Responsive {
  // Breakpoints (following Material Design guidelines)
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1200;

  /// Check if current screen is mobile size (< 600px)
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  /// Check if current screen is tablet size (600px - 1200px)
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileBreakpoint &&
      MediaQuery.of(context).size.width < tabletBreakpoint;

  /// Check if current screen is desktop size (>= 1200px)
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  /// Get adaptive number of grid columns based on screen size
  static int gridColumns(
    BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 4,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  /// Get adaptive padding based on screen size
  static double padding(
    BuildContext context, {
    double mobile = 16.0,
    double tablet = 24.0,
    double desktop = 32.0,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  /// Get adaptive font size based on screen size
  static double fontSize(
    BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }

  /// Get screen width
  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  /// Get screen height
  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;
}
