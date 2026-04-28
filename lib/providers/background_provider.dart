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
    // 監聽雲端設定，實現背景同步
    ref.listen(cloudSettingsProvider, (previous, next) {
      final cloudSettings = next.value;
      if (cloudSettings != null) {
        Color? remoteColor;
        double? remoteOpacity;
        bool changed = false;

        if (cloudSettings.containsKey('bg_color')) {
          remoteColor = Color(cloudSettings['bg_color']);
          if (state.color?.value != remoteColor.value) changed = true;
        }
        if (cloudSettings.containsKey('bg_opacity')) {
          remoteOpacity = (cloudSettings['bg_opacity'] as num).toDouble();
          if (state.opacity != remoteOpacity) changed = true;
        }

        if (changed) {
          state = state.copyWith(
            color: remoteColor ?? state.color,
            opacity: remoteOpacity ?? state.opacity,
            isCustom: true,
            imagePath: null, // 跨裝置目前不自動載入本地圖片路徑
          );
          final storage = ref.read(storageServiceProvider);
          storage.saveBackgroundSettings(state.color?.value, null, true, state.opacity);
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
    
    // 將最新設定同步到雲端
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      final Map<String, dynamic> updates = {
        'bg_opacity': state.opacity,
      };
      if (state.color != null) {
        updates['bg_color'] = state.color!.value;
      }
      firestore.updateSettings(updates);
    }
  }
}

final backgroundProvider = NotifierProvider<BackgroundNotifier, BackgroundState>(
  () => BackgroundNotifier(),
);
