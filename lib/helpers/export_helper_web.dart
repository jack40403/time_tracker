import 'dart:html' as html;

Future<void> saveAndShareFile(String content, String fileName) async {
  final bytes = html.Blob(['\uFEFF', content], 'text/csv;charset=utf-8;');
  final url = html.Url.createObjectUrlFromBlob(bytes);
  
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
    
  html.Url.revokeObjectUrl(url);
}
