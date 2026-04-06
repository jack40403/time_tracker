import 'package:flutter/widgets.dart';

Widget buildPlatformImage(String path, {Key? key, BoxFit fit = BoxFit.cover, Widget Function(BuildContext, Object, StackTrace?)? errorBuilder}) {
  return Image.network(
    path,
    key: key,
    fit: fit,
    errorBuilder: errorBuilder,
  );
}
