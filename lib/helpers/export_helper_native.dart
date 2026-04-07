import 'dart:io';
import 'dart:convert'; // 新增
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveAndShareFile(String content, String fileName) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  
  // Write content. Use BOM only for CSV to help Excel detect UTF-8.
  if (fileName.endsWith('.csv')) {
    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(content)]);
  } else {
    await file.writeAsString(content);
  }
  
  // Share the file natively
  await Share.shareXFiles(
    [XFile(file.path)], 
    text: fileName.endsWith('.csv') ? 'Elite Tracker: 時段日誌匯出' : 'Elite Tracker: 數據備份'
  );
}
