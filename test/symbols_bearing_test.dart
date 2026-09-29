import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphs/glyphs.dart';
import 'package:path_drawing/path_drawing.dart';

const _size = 24.0;
const _pixelRatio = 3.0;
const _ink = Color(0xFF000000);

void main() {
  setUpAll(() async {
    final bytes = File('lib/fonts/GlyphsSymbols.ttf').readAsBytesSync();
    await (FontLoader(
      'packages/glyphs/GlyphsSymbols',
    )..addFont(Future.value(bytes.buffer.asByteData()))).load();
  });

  testWidgets('GlyphsSymbols.arrow_back_ios_new inks where its outline lies', (
    tester,
  ) async {
    final svg = File(
      'assets/svgs/symbols/arrow_back_ios_new.svg',
    ).readAsStringSync();
    final outline = parseSvgPathData(
      RegExp(r'\sd="([^"]+)"').firstMatch(svg)!.group(1)!,
    );
    final iconKey = GlobalKey();
    final outlineKey = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: iconKey,
                child: Icon(
                  GlyphsSymbols.arrow_back_ios_new,
                  size: _size,
                  color: _ink,
                ),
              ),
              RepaintBoundary(
                key: outlineKey,
                child: CustomPaint(
                  size: const Size.square(_size),
                  painter: _OutlinePainter(outline),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final iconBox = await _inkBox(tester, iconKey);
    final outlineBox = await _inkBox(tester, outlineKey);
    for (final (edge, icon, drawn) in [
      ('left', iconBox.left, outlineBox.left),
      ('top', iconBox.top, outlineBox.top),
      ('right', iconBox.right, outlineBox.right),
      ('bottom', iconBox.bottom, outlineBox.bottom),
    ]) {
      expect(icon, closeTo(drawn, 1), reason: '$edge edge');
    }
  });
}

class _OutlinePainter extends CustomPainter {
  _OutlinePainter(this.outline);

  final Path outline;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 960);
    canvas.drawPath(outline, Paint()..color = _ink);
  }

  @override
  bool shouldRepaint(_OutlinePainter old) => old.outline != outline;
}

/// The bounding box, in physical pixels, of the pixels at least half inked.
Future<Rect> _inkBox(WidgetTester tester, GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final (width, pixels) = (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final width = image.width;
    image.dispose();
    return (width, data!.buffer.asUint8List());
  }))!;
  var left = width, top = width, right = -1, bottom = -1;
  for (var i = 3; i < pixels.length; i += 4) {
    if (pixels[i] < 128) continue;
    final x = (i ~/ 4) % width;
    final y = (i ~/ 4) ~/ width;
    if (x < left) left = x;
    if (x > right) right = x;
    if (y < top) top = y;
    if (y > bottom) bottom = y;
  }
  expect(right, isNonNegative, reason: 'no ink');
  return Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    right + 1.0,
    bottom + 1.0,
  );
}
