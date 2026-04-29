import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'services/update_service.dart';
import 'services/background_timer_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'providers/layout_provider.dart';
import 'providers/theme_provider.dart';
import 'firebase_options.dart';
import 'pages/main_screen.dart';
import 'widgets/background_wrapper.dart';
import 'widgets/app_lifecycle_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Main Entry Point
// ==========================================

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // 保留原生啟動圖，直到我們手動移除
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialize App
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  final prefs = await SharedPreferences.getInstance();
  
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    await initializeService();
    await NotificationService.init();
  }

  // 強制延遲 2 秒，確保資源與字體完全讀取，避免「叉叉」圖示出現
  await Future.delayed(const Duration(seconds: 2));
  
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const TimeTrackerApp(),
    ),
  );

  // 移除原生啟動圖，開始 Flutter 層級的漸淡動畫
  FlutterNativeSplash.remove();

  // Passive initial update check
  Future.delayed(const Duration(seconds: 1), () {
    final container = ProviderScope.containerOf(WidgetsBinding.instance.rootElement!);
    container.read(updateProvider.notifier).checkUpdates();
  });
}

class TimeTrackerApp extends ConsumerWidget {
  const TimeTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    
    final baseLightTextTheme = GoogleFonts.outfitTextTheme();
    final baseDarkTextTheme = GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme);

    TextTheme enlarge(TextTheme base) => base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontSize: 36),
      displayMedium: base.displayMedium?.copyWith(fontSize: 32),
      displaySmall: base.displaySmall?.copyWith(fontSize: 28),
      headlineLarge: base.headlineLarge?.copyWith(fontSize: 26, fontWeight: FontWeight.bold),
      headlineMedium: base.headlineMedium?.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
      headlineSmall: base.headlineSmall?.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
      titleLarge: base.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
      titleMedium: base.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 16),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 14),
      bodySmall: base.bodySmall?.copyWith(fontSize: 12),
      labelLarge: base.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
      labelMedium: base.labelMedium?.copyWith(fontSize: 12),
      labelSmall: base.labelSmall?.copyWith(fontSize: 11),
    );

    return MaterialApp(
      title: 'Me Time',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0077B6),
          primary: const Color(0xFF0077B6),
          secondary: const Color(0xFFFFD60A),
          surface: const Color(0xFFFFFDE7),
        ),
        useMaterial3: true,
        textTheme: enlarge(baseLightTextTheme),
        cardTheme: CardThemeData(
          color: const Color(0xFFFFFDE7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF1A1A2E), width: 3),
          ),
          elevation: 0,
          margin: const EdgeInsets.all(8),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF1A1A2E), width: 2),
          ),
          backgroundColor: Colors.white,
          selectedColor: const Color(0xFFFFD60A),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFFFFFDE7),
          indicatorColor: const Color(0xFFFFD60A),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
          ),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(size: 26, color: Color(0xFF1A1A2E));
            }
            return const IconThemeData(size: 26, color: Color(0xFF0077B6));
          }),
          elevation: 0,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFFFFFDE7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF1A1A2E), width: 3),
          ),
          elevation: 0,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF1A1A2E),
          contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0077B6),
          brightness: Brightness.dark,
          surface: const Color(0xFF1A1A2E),
        ),
        useMaterial3: true,
        textTheme: enlarge(baseDarkTextTheme),
        cardTheme: CardThemeData(
          color: const Color(0xFF0D2137),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF48CAE4), width: 2.5),
          ),
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF1A1A2E),
          indicatorColor: const Color(0xFFFFD60A),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(size: 26, color: Color(0xFF1A1A2E));
            }
            return const IconThemeData(size: 26, color: Color(0xFF48CAE4));
          }),
          elevation: 0,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF0D2137),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF48CAE4), width: 2.5),
          ),
          elevation: 0,
        ),
      ),
      home: const SplashFadeWrapper(
        child: AppLifecycleManager(
          child: BackgroundWrapper(
            child: MainScreen(),
          ),
        ),
      ),
    );
  }
}

/// 漸影啟動包裝器
/// 提供從啟動圖到主介面的平滑過度
class SplashFadeWrapper extends StatefulWidget {
  final Widget child;
  const SplashFadeWrapper({super.key, required this.child});

  @override
  State<SplashFadeWrapper> createState() => _SplashFadeWrapperState();
}

class _SplashFadeWrapperState extends State<SplashFadeWrapper> {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    // 當組件掛載後，立即開始淡出動畫
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() => _visible = false);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 主應用內容
        widget.child,
        
        // 浮動在上面的淡出層（模擬啟動圖）
        if (_visible || true) // 保留組件直到透明度變為 0
        IgnorePointer(
          ignoring: !_visible,
          child: AnimatedOpacity(
            opacity: _visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            onEnd: () => setState(() => _visible = false),
            child: Container(
              color: const Color(0xFF1A237E), // 與原生啟動色一致的深錠藍
              child: Center(
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 256, // 放大顯示，具備高級感
                  height: 256,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
