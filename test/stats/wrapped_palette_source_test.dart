import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/stats/wrapped/wrapped_media.dart';

void main() {
  test('a TMDB backdrop is read at w300 for its tint', () {
    final light = paletteSource(ImageData(
        path: 'https://image.tmdb.org/t/p/w1280/abc.jpg', key: 'k'));
    expect(light.path, 'https://image.tmdb.org/t/p/w300/abc.jpg');
    expect(light.key, 'k:palette');
  });

  test('a Jellyfin backdrop is asked small, other parameters kept', () {
    final light = paletteSource(ImageData(
        path: 'https://jf.example/Items/1/Images/Backdrop/0'
            '?tag=t&fillHeight=1080&fillWidth=1920&quality=90',
        key: 'k'));
    final query = Uri.parse(light.path).queryParameters;
    expect(query['fillWidth'], '320');
    expect(query['fillHeight'], '180');
    expect(query['tag'], 't');
    expect(query['quality'], '90');
  });

  test('a local or unsized image is left alone', () {
    final file = ImageData(path: '/tmp/a.jpg', key: 'k');
    expect(paletteSource(file), same(file));
    final orig = ImageData(path: 'https://jf.example/Items/1/Images/Primary');
    expect(paletteSource(orig), same(orig));
  });
}
