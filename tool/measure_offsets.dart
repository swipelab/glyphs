// Measures the **minimum enclosing circle (MEC) center** of each glyph by
// rendering it through the same paragraph configuration Flutter's `Icon`
// uses, then running Welzl's algorithm on the ink silhouette. The MEC
// center is what a circular FAB-like container should be aligned with:
// every extreme ink point sits on the MEC boundary, so they're equidistant
// from the MEC center (and thus from any larger concentric circle).
//
// Writes assets/offsets.json:
//   { "0xE013": [dx, dy], ... }
// where (dx, dy) are the *correction* (em-fractions) to apply via
// Transform.translate(Offset(dx*size, dy*size)) to bring the glyph's MEC
// center to the center of the size×size box that Flutter Icon renders into.
//
// Run with:
//   flutter test tool/measure_offsets.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _cpPath = 'assets/codepoints.json';
const _outPath = 'assets/offsets.json';
const _renderSize = 256.0; // Icon (paragraph) size used for measurement.
const _canvasSize = 512.0; // Larger than paragraph so shifted glyphs don't clip.
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
/// underlying `RichText` builds), then computes the center of its minimum
/// enclosing circle (Welzl's algorithm on silhouette pixels).
Future<ui.Offset?> _measureGlyph(int cp, String family) async {
  final size = _renderSize;
  final canvasSize = _canvasSize;
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
    ))
    ..addText(String.fromCharCode(cp));
  final paragraph = builder.build()..layout(ui.ParagraphConstraints(width: size));

  if (cp == 0xE012) {
    stdout.writeln('  paragraph.height=${paragraph.height} '
        'maxIntrinsicWidth=${paragraph.maxIntrinsicWidth} '
        'longestLine=${paragraph.longestLine} '
        'alphabeticBaseline=${paragraph.alphabeticBaseline}');
  }
  final saveFirst = cp == 0xE012;

  // Draw the paragraph centered in the larger canvas. Canvas is 2× paragraph
  // size so heavily-baked glyphs don't clip at the edges. The paragraph
  // center — which is what Icon's size×size box treats as viewBox center —
  // sits at (canvasSize/2, canvasSize/2).
  final dxOffset = (canvasSize - paragraph.maxIntrinsicWidth) / 2;
  final dyOffset = (canvasSize - paragraph.height) / 2;

  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, canvasSize, canvasSize),
    ui.Paint()..color = const ui.Color(0xFF000000),
  );
  canvas.drawParagraph(paragraph, ui.Offset(dxOffset, dyOffset));
  final img = await rec
      .endRecording()
      .toImage(canvasSize.toInt(), canvasSize.toInt());
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
  final w = canvasSize.toInt();

  // Silhouette pixels (ink with at least one background 4-neighbor). Only
  // boundary pixels can be on the MEC, so this trims the candidate set
  // ~100× and keeps Welzl's per-glyph cost at a few ms.
  bool isInk(int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= w) return false;
    return data[(y * w + x) * 4] >= 64;
  }
  final pts = <_P>[];
  for (int y = 0; y < w; y++) {
    for (int x = 0; x < w; x++) {
      if (!isInk(x, y)) continue;
      if (!isInk(x - 1, y) ||
          !isInk(x + 1, y) ||
          !isInk(x, y - 1) ||
          !isInk(x, y + 1)) {
        pts.add(_P(x.toDouble(), y.toDouble()));
      }
    }
  }
  if (pts.isEmpty) return null;

  final mec = _welzl(pts);
  // Offset returned in em-fractions relative to the PARAGRAPH (= Icon box)
  // center, not the canvas center — they're the same point since we centered
  // the paragraph in the canvas.
  return ui.Offset(
    (canvasSize / 2 - mec.x) / size,
    (canvasSize / 2 - mec.y) / size,
  );
}

class _P {
  final double x;
  final double y;
  const _P(this.x, this.y);
}

class _Circle {
  final double x;
  final double y;
  final double r;
  const _Circle(this.x, this.y, this.r);
  static const _zero = _Circle(0, 0, 0);
  bool contains(_P p) {
    final dx = p.x - x;
    final dy = p.y - y;
    return dx * dx + dy * dy <= r * r + 1e-6;
  }
}

_Circle _circleFrom2(_P a, _P b) {
  final cx = (a.x + b.x) / 2;
  final cy = (a.y + b.y) / 2;
  final dx = a.x - cx;
  final dy = a.y - cy;
  return _Circle(cx, cy, math.sqrt(dx * dx + dy * dy));
}

_Circle _circleFrom3(_P a, _P b, _P c) {
  final ax = a.x, ay = a.y, bx = b.x, by = b.y, cx = c.x, cy = c.y;
  final d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by));
  if (d.abs() < 1e-10) return _circleFrom2(a, c);
  final ux = ((ax * ax + ay * ay) * (by - cy) +
          (bx * bx + by * by) * (cy - ay) +
          (cx * cx + cy * cy) * (ay - by)) /
      d;
  final uy = ((ax * ax + ay * ay) * (cx - bx) +
          (bx * bx + by * by) * (ax - cx) +
          (cx * cx + cy * cy) * (bx - ax)) /
      d;
  final rx = ux - ax;
  final ry = uy - ay;
  return _Circle(ux, uy, math.sqrt(rx * rx + ry * ry));
}

/// Welzl's minimum enclosing circle (incremental form, shuffled input).
_Circle _welzl(List<_P> pts) {
  final shuffled = List<_P>.of(pts)..shuffle();
  _Circle mec = _Circle._zero;
  for (int i = 0; i < shuffled.length; i++) {
    if (!mec.contains(shuffled[i])) {
      mec = _Circle(shuffled[i].x, shuffled[i].y, 0);
      for (int j = 0; j < i; j++) {
        if (!mec.contains(shuffled[j])) {
          mec = _circleFrom2(shuffled[i], shuffled[j]);
          for (int k = 0; k < j; k++) {
            if (!mec.contains(shuffled[k])) {
              mec = _circleFrom3(shuffled[i], shuffled[j], shuffled[k]);
            }
          }
        }
      }
    }
  }
  return mec;
}
