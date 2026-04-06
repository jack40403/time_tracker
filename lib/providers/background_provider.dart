import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'storage_provider.dart';
import 'firestore_provider.dart';

class BackgroundState {
  final Color? color;
  final String? imagePath;
  final bool isCustom;
  final double opacity;

  BackgroundState({this.color, this.imagePath, this.isCustom = false, this.opacity = 0.2});

  BackgroundState copyWith({Color? color, String? imagePath, bool? isCustom, double? opacity}) {
    return BackgroundState(
      color: color ?? this.color,
      imagePath: imagePath ?? this.imagePath,
      isCustom: isCustom ?? this.isCustom,
      opacity: opacity ?? this.opacity,
    );
  }
}

class BackgroundNotifier extends Notifier<BackgroundState> {
  @override
  BackgroundState build() {
    // Sync from cloud when settings change
    ref.listen(cloudSettingsProvider, (previous, next) {
      final cloudSettings = next.value;
      if (cloudSettings != null && cloudSettings.containsKey('bg_color')) {
        final int colorVal = cloudSettings['bg_color'];
        final Color cloudColor = Color(colorVal);
        
        if (state.color?.value != cloudColor.value) {
          state = state.copyWith(color: cloudColor, isCustom: true, imagePath: null);
          final storage = ref.read(storageServiceProvider);
          storage.saveBackgroundSettings(cloudColor.value, null, true, state.opacity);
        }
      }
    });

    final storage = ref.read(storageServiceProvider);
    final data = storage.loadBackgroundSettings();
    return BackgroundState(
      color: data['color'] != null ? Color(data['color']) : null,
      imagePath: data['image'],
      isCustom: data['isCustom'] ?? false,
      opacity: data['opacity'] ?? 0.2,
    );
  }

  Future<void> updateColor(Color color) async {
    state = state.copyWith(color: color, isCustom: true, imagePath: null);
    _save();
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      state = state.copyWith(imagePath: image.path, isCustom: true, color: null);
      _save();
    }
  }

  void reset() {
    state = BackgroundState(isCustom: false, opacity: 0.2);
    _save();
  }

  void updateOpacity(double value) {
    state = state.copyWith(opacity: value);
    _save();
  }

  void _save() {
    final storage = ref.read(storageServiceProvider);
    storage.saveBackgroundSettings(state.color?.value, state.imagePath, state.isCustom, state.opacity);
    
    // Sync color to cloud if applicable
    if (state.color != null) {
      final firestore = ref.read(firestoreServiceProvider);
      firestore?.updateSettings({'bg_color': state.color!.value});
    }
  }
}

final backgroundProvider = NotifierProvider<BackgroundNotifier, BackgroundState>(
  () => BackgroundNotifier(),
);
