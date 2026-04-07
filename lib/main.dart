import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/update_service.dart';
import 'services/background_timer_service.dart';
import 'services/storage_service.dart';
import 'providers/layout_provider.dart';
import 'providers/theme_provider.dart';
import 'firebase_options.dart';
import 'pages/main_screen.dart';
import 'widgets/background_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart' as shorebird_sdk;

// Main Entry Point
// ==========================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Shorebird separately using named sdk to avoid constructor ambiguity
  final shorebird = shorebird_sdk.ShorebirdUpdater();
  
  // Check for updates automatically on startup if supported
  if (!kIsWeb && shorebird.isAvailable) {
    shorebird.readCurrentPatch().then((patch) {
      if (patch != null) {
        debugPrint('Elite Tracker Current Shorebird Patch: ${patch.number}');
      } else {
        debugPrint('Elite Tracker: No patch installed yet.');
      }
    });
  }
  
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
  }
  
  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(StorageService(prefs)),
      ],
      child: const TimeTrackerApp(),
    ),
  );

  // Passive initial update check
  Future.delayed(const Duration(seconds: 3), () {
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF)),
        useMaterial3: true,
        textTheme: enlarge(baseLightTextTheme),
        navigationBarTheme: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          iconTheme: WidgetStateProperty.all(const IconThemeData(size: 28)),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
          surface: const Color(0xFF121212),
        ),
        useMaterial3: true,
        textTheme: enlarge(baseDarkTextTheme),
        navigationBarTheme: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          iconTheme: WidgetStateProperty.all(const IconThemeData(size: 28)),
        ),
      ),
      home: const BackgroundWrapper(child: MainScreen()),
    );
  }
}
