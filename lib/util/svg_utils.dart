import 'package:flutter_svg/flutter_svg.dart';

class SvgUtils {
  static List<String> allSvgs = [
    'icons/kinos_signature_final.svg',
    'icons/kinos_wordmark_final.svg',
    'icons/kinos_icon.svg',
    'icons/kinos_icon_outline.svg',
    'icons/tomato.svg',
    'icons/popcorn_bucket.svg'
  ];

  static Future<void> preCacheSVGs() async {
    try {
      for (final path in allSvgs) {
        final loadSvg = SvgAssetLoader(path);
        await svg.cache.putIfAbsent(
          loadSvg.cacheKey(null),
          () => loadSvg.loadBytes(null),
        );
      }
    } catch (e) {
      print(e);
    }
  }
}
