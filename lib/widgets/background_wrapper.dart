import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/background_provider.dart';
import '../providers/app_theme_provider.dart';
import '../theme/app_themes.dart';
import '../helpers/platform_image_helper.dart';

class BackgroundWrapper extends ConsumerWidget {
  final Widget child;
  const BackgroundWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgState = ref.watch(backgroundProvider);
    final appTheme = ref.watch(currentAppThemeProvider);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: _buildBackground(bgState, appTheme),
            ),
          ),
          Positioned.fill(child: ThemedBubbles(theme: appTheme)),
          child,
        ],
      ),
    );
  }

  Widget _buildBackground(BackgroundState state, AppTheme t) {
    if (!state.isCustom) {
      return AnimatedContainer(
        key: ValueKey(t.id),
        duration: const Duration(milliseconds: 400),
        decoration: t.backgroundDecoration,
      );
    }

    if (state.imagePath != null) {
      return Opacity(
        opacity: state.opacity,
        child: getPlatformImage(
          state.imagePath!,
          key: ValueKey(state.imagePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey),
        ),
      );
    }

    return Opacity(
      opacity: state.opacity,
      child: Container(key: ValueKey(state.color?.value), color: state.color),
    );
  }
}

// ─── Themed bubbles / background decoration ──────────────────────────────────

class ThemedBubbles extends StatelessWidget {
  final AppTheme theme;
  const ThemedBubbles({super.key, required this.theme});

  static const _bubbles = [
    _BubbleCfg(size: 80, top: 40, left: -20),
    _BubbleCfg(size: 50, top: 130, right: 10),
    _BubbleCfg(size: 35, top: 220, left: 20),
    _BubbleCfg(size: 60, bottom: 220, right: -15),
    _BubbleCfg(size: 28, bottom: 340, left: 28),
    _BubbleCfg(size: 45, bottom: 120, left: 60),
  ];

  @override
  Widget build(BuildContext context) {
    final style = theme.bubbleStyle;
    if (style == 'none') return const SizedBox.shrink();

    return IgnorePointer(
      child: Stack(
        children: [
          if (style == 'cartoon') ..._cartoonBubbles(Colors.white),
          if (style == 'cartoon-dark') ..._cartoonBubbles(const Color(0xFF48CAE4)),
          if (style == 'pixel') const _PixelBackground(),
          if (style == 'pastel') const _PastelBlobs(),
        ],
      ),
    );
  }

  List<Widget> _cartoonBubbles(Color baseColor) {
    return _bubbles.map((b) {
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
            color: baseColor.withOpacity(0.13),
            border: Border.all(color: baseColor.withOpacity(0.22), width: 2),
          ),
        ),
      );
    }).toList();
  }
}

class _BubbleCfg {
  final double size;
  final double? top, bottom, left, right;
  const _BubbleCfg({required this.size, this.top, this.bottom, this.left, this.right});
}

class _PixelBackground extends StatelessWidget {
  const _PixelBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _PixelDotPainter(),
      ),
    );
  }
}

class _PixelDotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x123D2F1F);
    const spacing = 18.0;
    const dotSize = 2.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawRect(Rect.fromLTWH(x, y, dotSize, dotSize), paint);
      }
    }
    // CRT scanlines
    final linePaint = Paint()..color = const Color(0x083D2F1F);
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PastelBlobs extends StatelessWidget {
  const _PastelBlobs();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -60, left: -60,
            child: _blob(180, const Color(0xFFFFB3C6), const Color(0xFFFFC9DE)),
          ),
          Positioned(
            bottom: 60, right: -40,
            child: _blob(220, const Color(0xFFC8B6FF), const Color(0xFFE2D4FF)),
          ),
          Positioned(
            top: 200, right: 20,
            child: _blob(120, const Color(0xFFFFE5EC), const Color(0xFFFFC9DE)),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color c1, Color c2) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [c1.withOpacity(0.55), c2.withOpacity(0.0)]),
      ),
    );
  }
}
