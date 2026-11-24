import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The brand logos bundled with the app (see tool/make_brand_assets.py): the
/// sloth icon and the sloth wordmark, each in the brand green (for white) and
/// cream (for the deep olive footer).
void main() {
  /// The colour that most of a logo's visible pixels are, as 0xRRGGBB.
  Future<({int width, int height, int colour, int visible})> look(WidgetTester tester, String asset) async {
    final data = await rootBundle.load(asset);
    late ui.Image image;
    late ByteData pixels;
    await tester.runAsync(() async {
      image = await decodeImageFromList(data.buffer.asUint8List());
      pixels = (await image.toByteData())!;
    });
    final counts = <int, int>{};
    var visible = 0;
    for (var i = 0; i < pixels.lengthInBytes; i += 4) {
      if (pixels.getUint8(i + 3) < 200) continue; // transparent or soft edge
      visible++;
      final colour = (pixels.getUint8(i) << 16) | (pixels.getUint8(i + 1) << 8) | pixels.getUint8(i + 2);
      counts[colour] = (counts[colour] ?? 0) + 1;
    }
    final dominant = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return (width: image.width, height: image.height, colour: dominant, visible: visible);
  }

  const green = 0x2C3F33; // the brand green
  const cream = 0xF6F3E9;

  group('the sloth icon', () {
    testWidgets('is bundled in the brand green and in cream, cropped to the artwork', (tester) async {
      for (final (asset, colour) in [
        ('assets/brand/sloth_icon_green.png', green),
        ('assets/brand/sloth_icon_cream.png', cream),
      ]) {
        final icon = await look(tester, asset);

        expect(icon.colour, colour, reason: asset);
        // Nearly square (the artwork is 2495 x 2304), with no margin of its own to size around.
        expect(icon.width / icon.height, closeTo(2495 / 2304, 0.02), reason: asset);
        expect(icon.height, 384, reason: asset);
        expect(icon.visible / (icon.width * icon.height), greaterThan(0.3), reason: '$asset is mostly artwork');
      }
    });
  });

  group('the sloth wordmark', () {
    testWidgets('is bundled in the brand green and in cream, cropped to the artwork', (tester) async {
      for (final (asset, colour) in [
        ('assets/brand/sloth_wordmark_green.png', green),
        ('assets/brand/sloth_wordmark_cream.png', cream),
      ]) {
        final wordmark = await look(tester, asset);

        expect(wordmark.colour, colour, reason: asset);
        expect(wordmark.width / wordmark.height, closeTo(3106 / 1221, 0.02), reason: asset);
        expect(wordmark.width, 800, reason: asset);
      }
    });
  });

  test('the logos are small enough not to slow the first load', () async {
    var total = 0;
    for (final asset in [
      'assets/brand/sloth_icon_green.png',
      'assets/brand/sloth_icon_cream.png',
      'assets/brand/sloth_wordmark_green.png',
      'assets/brand/sloth_wordmark_cream.png',
    ]) {
      total += (await rootBundle.load(asset)).lengthInBytes;
    }

    expect(total, lessThan(300 * 1024));
  });
}
