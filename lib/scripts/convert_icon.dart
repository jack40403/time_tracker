import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final inputPath = 'web/icons/Icon-192.jpg';
  final outputPath = 'web/icons/final_logo.png';

  final bytes = await File(inputPath).readAsBytes();
  final image = img.decodeImage(bytes);

  if (image == null) {
    print('Error: Could not decode image $inputPath');
    return;
  }

  final pngBytes = img.encodePng(image);
  await File(outputPath).writeAsBytes(pngBytes);

  print('Success: Converted $inputPath to $outputPath (Real PNG)');
}
