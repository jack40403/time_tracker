import 'export_helper_stub.dart'
    if (dart.library.html) 'export_helper_web.dart'
    if (dart.library.io) 'export_helper_native.dart';

Future<void> exportCSV(String content, String fileName) async {
  await saveAndShareFile(content, fileName);
}
