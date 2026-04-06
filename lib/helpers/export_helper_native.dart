import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveAndShareFile(String content, String fileName) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  
  // Write content (UTF-8 with BOM for Excel)
  await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...content.codeUnits]);
  
  // Share the file natively
  await Share.shareXFiles([XFile(file.path)], text: 'Time Tracker Export');
}
