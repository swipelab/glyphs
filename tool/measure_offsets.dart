// Measures the mass-center offset of each glyph by rendering it through
// Flutter's actual `Icon` widget into a RepaintBoundary, then computing the
// centroid of the rendered pixels. This is the only source of truth that
// matches what users see — measuring the SVG path or a raw TextPainter
// disagrees with Icon by font-metric quirks (line height, baseline placement,
// sidebearings).
//
// Writes assets/offsets.json:
//   { "0xE013": [dx, dy], ... }
// where (dx, dy) are the *correction* (em-fractions) to apply via
// Transform.translate(Offset(dx*size, dy*size)) to bring the glyph's visual
// mass to the center of the size×size box that Flutter Icon renders into.
//
// Run with:
//   flutter test tool/measure_offsets.dart

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _cpPath = 'assets/codepoints.json';
const _outPath = 'assets/offsets.json';
const _renderSize = 256.0; // Icon size used for measurement.
const _threshold = 0.001; // ~0.25px at 256 — skip "already centered".

const _styleFamily = <String, String>{
  'solid': 'GlyphsSolid',
  'regular': 'GlyphsRegular',
  'brands': 'GlyphsBrands',
};

void main() {
  test(
    'measure mass-center offsets',
    timeout: const Timeout(Duration(minutes: 30)),
    () async {
      // Manually load fonts: when running outside the widget tree (raw
      // Paragraph), flutter_test does not auto-register the package's
      // pubspec fonts, so glyphs render as .notdef tofu boxes.
      for (final family in _styleFamily.values) {
        final loader = FontLoader(family);
        final bytes =
            File('lib/fonts/$family.ttf').readAsBytesSync().buffer.asByteData();
        loader.addFont(Future.value(bytes));
        await loader.load();
        stdout.writeln('loaded font: $family');
      }

      final cpJson = jsonDecode(File(_cpPath).readAsStringSync())
          as Map<String, dynamic>;
      final result = <String, List<double>>{};
      var processed = 0;

      for (final styleEntry in _styleFamily.entries) {
        final style = styleEntry.key;
        final family = styleEntry.value;
        final cpMap = cpJson[style] as Map<String, dynamic>?;
        if (cpMap == null) continue;
        // ignore: avoid_print
        stdout.writeln('-- style: $style (${cpMap.length} glyphs) --');

        for (final entry in cpMap.entries) {
          final name = entry.key;
          final cpStr = entry.value as String;
          final cp = int.parse(cpStr.substring(2), radix: 16);

          final off = await _measureGlyph(cp, family);
          processed++;
          if (off == null) {
            stdout.writeln('[$processed] $style/$name $cpStr -> (empty)');
            continue;
          }
          final dx = off.dx;
          final dy = off.dy;
          final skipped = dx.abs() < _threshold && dy.abs() < _threshold;
          stdout.writeln(
            '[$processed] $style/$name $cpStr -> '
            'dx=${dx.toStringAsFixed(4)} dy=${dy.toStringAsFixed(4)}'
            '${skipped ? ' (skip)' : ''}',
          );
          if (skipped) continue;
          result[cpStr] = [
            double.parse(dx.toStringAsFixed(4)),
            double.parse(dy.toStringAsFixed(4)),
          ];
        }
      }

      final sorted = Map.fromEntries(
        result.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      );
      File(_outPath).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(sorted),
      );
      stdout.writeln('wrote $_outPath (${sorted.length} entries)');
    },
  );
}

/// Renders the glyph using a raw [ui.Paragraph] (which is what `Icon`'s
/// underlying `RichText` builds), then measures the centroid pixel by pixel.
Future<ui.Offset?> _measureGlyph(int cp, String family) async {
  final size = _renderSize;
  final builder = ui.ParagraphBuilder(
    ui.ParagraphStyle(
      textAlign: ui.TextAlign.left,
      fontFamily: family,
      fontSize: size,
      // Mirror Flutter's Icon style so the measurement matches what users see.
      height: 1.0,
      textHeightBehavior: const ui.TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
        leadingDistribution: ui.TextLeadingDistribution.even,
      ),
    ),
  )
    ..pushStyle(ui.TextStyle(
      color: const ui.Color(0xFFFFFFFF),
      fontFamily: family,
      fontSize: size,
      fontFamilyFallback: const <String>[],
      // Resolve from this package's fonts.
    ))
    ..addText(String.fromCharCode(cp));
  final paragraph = builder.build()..layout(ui.ParagraphConstraints(width: size));

  if (cp == 0xE012) {
    stdout.writeln('  paragraph.height=${paragraph.height} '
        'maxIntrinsicWidth=${paragraph.maxIntrinsicWidth} '
        'longestLine=${paragraph.longestLine} '
        'alphabeticBaseline=${paragraph.alphabeticBaseline}');
  }
  // Save the rendered xmark for visual verification of the font being used.
  final saveFirst = cp == 0xE012;

  // Position the paragraph the way Icon's Center wraps RichText: centered
  // inside a size×size box.
  final dxOffset = (size - paragraph.maxIntrinsicWidth) / 2;
  final dyOffset = (size - paragraph.height) / 2;

  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, size, size),
    ui.Paint()..color = const ui.Color(0xFF000000),
  );
  canvas.drawParagraph(paragraph, ui.Offset(dxOffset, dyOffset));
  final img = await rec.endRecording().toImage(size.toInt(), size.toInt());
  if (saveFirst) {
    final pngBd = await img.toByteData(format: ui.ImageByteFormat.png);
    if (pngBd != null) {
      File('tool/xmark_rendered.png')
          .writeAsBytesSync(pngBd.buffer.asUint8List());
      stdout.writeln('  saved tool/xmark_rendered.png');
    }
  }
  final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  img.dispose();
  if (bd == null) return null;
  final data = bd.buffer.asUint8List();
  final w = size.toInt();

  double mxsum = 0, mysum = 0, msum = 0;
  for (int y = 0; y < w; y++) {
    for (int x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final v = data[i];
      if (v == 0) continue;
      final wt = v / 255.0;
      mxsum += x * wt;
      mysum += y * wt;
      msum += wt;
    }
  }
  if (msum == 0) return null;
  final cx = mxsum / msum;
  final cy = mysum / msum;
  return ui.Offset(
    (size / 2 - cx) / size,
    (size / 2 - cy) / size,
  );
}
