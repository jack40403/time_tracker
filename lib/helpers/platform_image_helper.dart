import 'package:flutter/widgets.dart';
import 'platform_image_helper_stub.dart'
    if (dart.library.html) 'platform_image_helper_web.dart'
    if (dart.library.js_util) 'platform_image_helper_web.dart'
    if (dart.library.io) 'platform_image_helper_native.dart';

Widget getPlatformImage(String path, {Key? key, BoxFit fit = BoxFit.cover, Widget Function(BuildContext, Object, StackTrace?)? errorBuilder}) {
  return buildPlatformImage(path, key: key, fit: fit, errorBuilder: errorBuilder);
}
