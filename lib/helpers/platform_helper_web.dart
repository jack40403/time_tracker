import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'dart:html' as html;

void reloadApp() {
  html.window.location.reload();
}

Future<String?> pickJsonFile() async {
  try {
    // Using the static pickFiles method which is more compatible in 11.0.2
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true, // Crucial for Web to get bytes
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        return utf8.decode(file.bytes!);
      }
    }
  } catch (e) {
    print('Web Picker Error: $e');
  }
  return null;
}
