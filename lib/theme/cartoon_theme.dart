import 'package:flutter/material.dart';

class CartoonTheme {
  // Core palette
  static const Color skyBlue = Color(0xFF48CAE4);
  static const Color oceanBlue = Color(0xFF0077B6);
  static const Color deepBlue = Color(0xFF023E8A);
  static const Color sunYellow = Color(0xFFFFD60A);
  static const Color goldenOrange = Color(0xFFFF8F00);
  static const Color warmYellow = Color(0xFFFFB300);
  static const Color creamWhite = Color(0xFFFFFDE7);
  static const Color inkBlack = Color(0xFF1A1A2E);
  static const Color softRed = Color(0xFFFF5252);
  static const Color softGrey = Color(0xFFE0E0E0);

  // Gradient
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [skyBlue, oceanBlue],
  );

  // Card decoration (white/cream cards with thick black border)
  static BoxDecoration cardDecoration({
    Color color = creamWhite,
    double radius = 24,
    double borderWidth = 3.5,
    double shadowOffset = 5,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: inkBlack, width: borderWidth),
      boxShadow: [
        BoxShadow(
          color: inkBlack,
          offset: Offset(shadowOffset, shadowOffset),
          blurRadius: 0,
        ),
      ],
    );
  }

  // Translucent panel (for category list, overlays)
  static BoxDecoration panelDecoration({double radius = 20}) {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.black.withOpacity(0.25), width: 2.5),
    );
  }

  // Chip decoration
  static BoxDecoration chipDecoration({required bool isSelected, required Color activeColor}) {
    return BoxDecoration(
      color: isSelected ? activeColor : Colors.white.withOpacity(0.88),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: inkBlack, width: 2.5),
      boxShadow: [
        BoxShadow(
          color: isSelected ? inkBlack : Colors.black.withOpacity(0.15),
          offset: Offset(isSelected ? 3 : 2, isSelected ? 3 : 2),
          blurRadius: 0,
        ),
      ],
    );
  }

  // Button decoration (yellow play button style)
  static BoxDecoration buttonDecoration({
    Color color = sunYellow,
    double radius = 50,
    double borderWidth = 4,
    double shadowOffset = 5,
  }) {
    return BoxDecoration(
      color: color,
      shape: radius >= 50 ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: radius < 50 ? BorderRadius.circular(radius) : null,
      border: Border.all(color: inkBlack, width: borderWidth),
      boxShadow: [
        BoxShadow(
          color: inkBlack,
          offset: Offset(shadowOffset, shadowOffset),
          blurRadius: 0,
        ),
      ],
    );
  }

  // Bubble positions for background decoration
  static List<_BubbleConfig> get bubbles => [
    _BubbleConfig(size: 80, top: 40, left: -20),
    _BubbleConfig(size: 50, top: 130, right: 10),
    _BubbleConfig(size: 35, top: 220, left: 20),
    _BubbleConfig(size: 60, bottom: 220, right: -15),
    _BubbleConfig(size: 28, bottom: 340, left: 28),
    _BubbleConfig(size: 45, bottom: 120, left: 60),
  ];
}

class _BubbleConfig {
  final double size;
  final double? top, bottom, left, right;
  const _BubbleConfig({required this.size, this.top, this.bottom, this.left, this.right});
}

// Reusable bubble background widget
class CartoonBubbles extends StatelessWidget {
  const CartoonBubbles({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: CartoonTheme.bubbles.map((b) {
          return Positioned(
            top: b.top,
            bottom: b.bottom,
            left: b.left,
            right: b.right,
            child: Container(
              width: b.size,
              height: b.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.13),
                border: Border.all(color: Colors.white.withOpacity(0.22), width: 2),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Cartoon-style AppBar
class CartoonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const CartoonAppBar({super.key, required this.title, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : CartoonTheme.inkBlack,
          letterSpacing: 1,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      actions: actions,
    );
  }
}

// Section label style
class CartoonSectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const CartoonSectionLabel({super.key, required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: Colors.white70,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
