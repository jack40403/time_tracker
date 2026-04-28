import 'dart:io';
import 'package:file_picker/file_picker.dart';

void reloadApp() {
  // Mobile platforms handle reload via manual restart or other mechanisms.
}

Future<String?> pickJsonFile() async {
  try {
    // In file_picker 11.0.2, the 'platform' static member might be replaced
    // or hidden in some configurations. Using the direct 'pickFiles' static method
    // is the most compatible way across Web/Native in this version.
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      return await file.readAsString();
    }
  } catch (e) {
    print('Native Picker Error: $e');
  }
  return null;
}
