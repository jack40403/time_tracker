import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_theme_provider.dart';
import '../theme/app_themes.dart';
import '../pages/main_screen.dart';
import '../widgets/background_wrapper.dart';
import '../widgets/app_lifecycle_manager.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _popCtrl;
  late final AnimationController _ringCtrl;
  late final AnimationController _sparkCtrl;
  late final AnimationController _bubbleCtrl;
  late final AnimationController _bobCtrl;

  // pop-in: scale 0→1.12→0.95→1
  late final Animation<double> _popScale;
  late final Animation<double> _popRotate;
  late final Animation<double> _popOpacity;

  // bob (idle)
  late final Animation<double> _bobOffset;

  // rings
  late final Animation<double> _ring1Scale;
  late final Animation<double> _ring1Opacity;
  late final Animation<double> _ring2Scale;
  late final Animation<double> _ring2Opacity;

  // sparks
  late final Animation<double> _sparkOpacity;
  late final Animation<double> _sparkY;

  bool _popped = false;

  @override
  void initState() {
    super.initState();

    _popCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _bobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _sparkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _bubbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // Pop in
    _popScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.12).chain(CurveTween(curve: Curves.elasticOut)), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 0.95), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 25),
    ]).animate(_popCtrl);

    _popRotate = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: -25.0 * math.pi / 180, end: 6.0 * math.pi / 180), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 6.0 * math.pi / 180, end: -2.0 * math.pi / 180), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -2.0 * math.pi / 180, end: 0.0), weight: 25),
    ]).animate(_popCtrl);

    _popOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _popCtrl, curve: const Interval(0, 0.25)),
    );

    // Bob
    _bobOffset = Tween(begin: 0.0, end: -5.0).animate(
      CurvedAnimation(parent: _bobCtrl, curve: Curves.easeInOut),
    );

    // Rings (two staggered)
    _ring1Scale = Tween(begin: 0.7, end: 1.6).animate(
      CurvedAnimation(parent: _ringCtrl, curve: const Interval(0, 0.5, curve: Curves.easeOut)),
    );
    _ring1Opacity = Tween(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _ringCtrl, curve: const Interval(0, 0.5)),
    );
    _ring2Scale = Tween(begin: 0.7, end: 1.6).animate(
      CurvedAnimation(parent: _ringCtrl, curve: const Interval(0.2, 0.7, curve: Curves.easeOut)),
    );
    _ring2Opacity = Tween(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _ringCtrl, curve: const Interval(0.2, 0.7)),
    );

    // Sparks
    _sparkOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 50),
    ]).animate(_sparkCtrl);

    _sparkY = Tween(begin: 4.0, end: -16.0).animate(
      CurvedAnimation(parent: _sparkCtrl, curve: Curves.easeOut),
    );

    // Start sequence
    _popCtrl.forward().then((_) {
      if (!mounted) return;
      // Start bob loop
      _bobCtrl.repeat(reverse: true);
      // Rings
      _ringCtrl.repeat();
      // Sparks after 150ms
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _sparkCtrl.repeat();
      });
      // Bubbles
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _bubbleCtrl.repeat();
      });
      // Navigate after ~1.8s total (700 pop + 1100 idle)
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (mounted && !_popped) {
          _popped = true;
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const AppLifecycleManager(
                child: BackgroundWrapper(child: MainScreen()),
              ),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _popCtrl.dispose();
    _bobCtrl.dispose();
    _ringCtrl.dispose();
    _sparkCtrl.dispose();
    _bubbleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(currentAppThemeProvider);
    const double iconSize = 160;
    const double ringSize = iconSize * 1.15;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: t.backgroundDecoration,
        child: Stack(
          children: [
            // Background decoration (no pointer interception needed for bubbles in splash)
            if (t.bubbleStyle == 'cartoon' || t.bubbleStyle == 'cartoon-dark')
              ..._buildCartoonBubbles(t),
            if (t.bubbleStyle == 'pastel')
              const _PastelBlobsSplash(),

            // Center stage
            Center(
              child: SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ring 1 (yellow)
                    AnimatedBuilder(
                      animation: _ringCtrl,
                      builder: (_, __) => Transform.scale(
                        scale: _ring1Scale.value,
                        child: Opacity(
                          opacity: _ring1Opacity.value.clamp(0.0, 1.0),
                          child: Container(
                            width: ringSize,
                            height: ringSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: t.action.withOpacity(0.7),
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Ring 2 (white/surface)
                    AnimatedBuilder(
                      animation: _ringCtrl,
                      builder: (_, __) => Transform.scale(
                        scale: _ring2Scale.value,
                        child: Opacity(
                          opacity: _ring2Opacity.value.clamp(0.0, 1.0),
                          child: Container(
                            width: ringSize,
                            height: ringSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: t.surface.withOpacity(0.55),
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // App icon (pop-in + bob)
                    AnimatedBuilder(
                      animation: Listenable.merge([_popCtrl, _bobCtrl]),
                      builder: (_, __) {
                        final scale = _popCtrl.isCompleted ? 1.0 : _popScale.value;
                        final rotate = _popCtrl.isCompleted ? 0.0 : _popRotate.value;
                        final opacity = _popCtrl.isCompleted ? 1.0 : _popOpacity.value;
                        final bobY = _popCtrl.isCompleted ? _bobOffset.value : 0.0;

                        return Transform.translate(
                          offset: Offset(0, bobY),
                          child: Transform.rotate(
                            angle: rotate,
                            child: Transform.scale(
                              scale: scale,
                              child: Opacity(
                                opacity: opacity.clamp(0.0, 1.0),
                                child: Container(
                                  width: iconSize,
                                  height: iconSize,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(iconSize * 0.18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.25),
                                        offset: const Offset(0, 12),
                                        blurRadius: 22,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(iconSize * 0.18),
                                    child: Image.asset(
                                      'assets/icon/app_icon.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Sparks (3 above the icon)
                    ...[
                      _SparkPos(xFrac: 0.5, color: const Color(0xFFFFD60A), scale: 1.0, delay: 0),
                      _SparkPos(xFrac: 0.34, color: Colors.white, scale: 0.7, delay: 0),
                      _SparkPos(xFrac: 0.66, color: Colors.white, scale: 0.7, delay: 0),
                    ].map((sp) => Positioned(
                      top: 280 * 0.10,
                      left: 280 * sp.xFrac - 18 * sp.scale,
                      child: AnimatedBuilder(
                        animation: _sparkCtrl,
                        builder: (_, __) => Opacity(
                          opacity: _sparkOpacity.value.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, _sparkY.value),
                            child: _SparkSvg(color: sp.color, scale: sp.scale),
                          ),
                        ),
                      ),
                    )),

                    // Bubbles flying out
                    ..._splashBubbles.map((b) => Positioned(
                      left: 280 * b.xFrac - b.size / 2,
                      top: 280 * b.yFrac - b.size / 2,
                      child: AnimatedBuilder(
                        animation: _bubbleCtrl,
                        builder: (_, __) {
                          final progress = _bubbleCtrl.value;
                          final opacity = progress < 0.06
                              ? progress / 0.06
                              : progress < 0.28
                                  ? 1.0
                                  : 1.0 - (progress - 0.28) / 0.72;
                          final tx = progress * b.ex;
                          final ty = progress * b.ey;
                          final sc = progress < 0.06 ? 0.0 : 1.0;
                          return Transform.translate(
                            offset: Offset(tx, ty),
                            child: Transform.scale(
                              scale: sc,
                              child: Opacity(
                                opacity: opacity.clamp(0.0, 1.0),
                                child: Container(
                                  width: b.size,
                                  height: b.size,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.88),
                                    border: Border.all(color: Colors.white.withOpacity(0.65), width: 2),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCartoonBubbles(AppTheme t) {
    final baseColor = t.bubbleStyle == 'cartoon-dark'
        ? const Color(0xFF48CAE4)
        : Colors.white;
    final positions = <Map<String, double?>>[
      {'size': 80, 'top': 40, 'left': -20},
      {'size': 50, 'top': 130, 'right': 10},
      {'size': 35, 'top': 220, 'left': 20},
      {'size': 60, 'bottom': 220, 'right': -15},
      {'size': 28, 'bottom': 340, 'left': 28},
      {'size': 45, 'bottom': 120, 'left': 60},
    ];
    return positions.map((p) => Positioned(
      top: p['top'],
      bottom: p['bottom'],
      left: p['left'],
      right: p['right'],
      child: Container(
        width: p['size'],
        height: p['size'],
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: baseColor.withOpacity(0.13),
          border: Border.all(color: baseColor.withOpacity(0.22), width: 2),
        ),
      ),
    )).toList();
  }
}

class _SparkPos {
  final double xFrac;
  final Color color;
  final double scale;
  final int delay;
  const _SparkPos({required this.xFrac, required this.color, required this.scale, required this.delay});
}

class _SparkSvg extends StatelessWidget {
  final Color color;
  final double scale;
  const _SparkSvg({required this.color, required this.scale});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(36 * scale, 20 * scale),
      painter: _SparkPainter(color: color),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final Color color;
  const _SparkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final h = size.height;
    canvas.drawLine(Offset(cx, h * 0.8), Offset(cx, h * 0.2), paint);
    canvas.drawLine(Offset(cx - size.width * 0.28, h * 0.6), Offset(cx - size.width * 0.39, h * 0.3), paint);
    canvas.drawLine(Offset(cx + size.width * 0.28, h * 0.6), Offset(cx + size.width * 0.39, h * 0.3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BubbleData {
  final double xFrac, yFrac, ex, ey, size;
  const _BubbleData(this.xFrac, this.yFrac, this.ex, this.ey, this.size);
}

const _splashBubbles = [
  _BubbleData(0.18, 0.30, -26, -44, 14),
  _BubbleData(0.82, 0.28,  38, -30, 10),
  _BubbleData(0.88, 0.68,  46,  34, 18),
  _BubbleData(0.12, 0.76, -40,  32, 12),
  _BubbleData(0.50, 0.90,   0,  42, 16),
  _BubbleData(0.24, 0.52, -46,   0,  8),
  _BubbleData(0.76, 0.52,  46,   0,  8),
];

class _PastelBlobsSplash extends StatelessWidget {
  const _PastelBlobsSplash();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(top: -60, left: -60, child: _blob(180, const Color(0xFFFFB3C6), const Color(0xFFFFC9DE))),
        Positioned(bottom: 60, right: -40, child: _blob(220, const Color(0xFFC8B6FF), const Color(0xFFE2D4FF))),
        Positioned(top: 200, right: 20, child: _blob(120, const Color(0xFFFFE5EC), const Color(0xFFFFC9DE))),
      ],
    );
  }

  Widget _blob(double size, Color c1, Color c2) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [c1.withOpacity(0.55), c2.withOpacity(0.0)]),
      ),
    );
  }
}
