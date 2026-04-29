import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/background_provider.dart';
import '../helpers/platform_image_helper.dart';
import '../theme/cartoon_theme.dart';

class BackgroundWrapper extends ConsumerWidget {
  final Widget child;
  const BackgroundWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgState = ref.watch(backgroundProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: _buildBackground(bgState, isDark),
            ),
          ),
          const Positioned.fill(child: CartoonBubbles()),
          child,
        ],
      ),
    );
  }

  Widget _buildBackground(BackgroundState state, bool isDark) {
    if (!state.isCustom) {
      return Container(
        key: const ValueKey('default'),
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D2137), Color(0xFF1A1A2E)],
                )
              : CartoonTheme.backgroundGradient,
        ),
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
