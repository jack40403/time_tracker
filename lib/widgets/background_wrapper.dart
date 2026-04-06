import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/background_provider.dart';
import '../helpers/platform_image_helper.dart';

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
          child,
        ],
      ),
    );
  }

  Widget _buildBackground(BackgroundState state, bool isDark) {
    if (!state.isCustom) {
      return Container(key: const ValueKey('default'), color: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FE));
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
