import 'package:flutter/material.dart';
import 'dart:math' as math;

class ResponsiveHelper {
  /// Base width for calculations (standard mobile width)
  static const double baseWidth = 375.0;

  /// Gets a scale factor based on screen width.
  /// 
  /// [minScale] and [maxScale] ensure the font doesn 't become unusable.
  static double getScale(BuildContext context, {double minScale = 0.85, double maxScale = 1.35}) {
    final width = MediaQuery.of(context).size.width;
    final scale = width / baseWidth;
    return math.max(minScale, math.min(maxScale, scale));
  }

  /// Returns a responsive font size.
  static double sp(BuildContext context, double size, {double? minScale, double? maxScale}) {
    final scale = getScale(context, minScale: minScale ?? 0.85, maxScale: maxScale ?? 1.35);
    return size * scale;
  }

  /// Returns a scale specifically for very large titles/timers
  static double getTimerScale(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 800) return 1.15; // Tablet/Desktop slightly larger
    if (width < 340) return 0.8;  // Very small phone smaller
    return 1.0;
  }
  
  /// Helper to check if it 's a wide screen
  static bool isWide(BuildContext context) => MediaQuery.of(context).size.width > 800;
  
  /// Helper to check if it 's a tablet-sized screen
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width <= 800;
  }
}
