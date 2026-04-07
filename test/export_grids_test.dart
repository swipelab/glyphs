// Generates 3 visual grids comparing icon centering strategies:
//   - viewBox: raw fit, no correction
//   - bbox:    shift so tight alpha bbox center sits on cell center
//   - mass:    shift so alpha-weighted centroid sits on cell center
//
// Output: test/out/grid_<style>_<strategy>_<page>.png
// Run with: flutter test test/export_grids_test.dart

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_drawing/path_drawing.dart';

const _svgRoot = 'assets/svgs';
const _styles = ['solid', 'regular', 'brands'];
const _outDir = 'test/out';
const _cell = 128;
const _cols = 16;
const _rows = 16;
const _padding = 16.0;

class IconSpec {
  final String name;
  final double vbW, vbH;
  final ui.Path path;
  IconSpec(this.name, this.vbW, this.vbH, this.path);
}

final _viewBoxRe = RegExp(r'viewBox="0 0 ([\d.]+) ([\d.]+)"');
final _dRe = RegExp(r'\sd="([^"]+)"');

IconSpec? _loadSvg(File f) {
  final s = f.readAsStringSync();
  final vb = _viewBoxRe.firstMatch(s);
  if (vb == null) return null;
  final ds = _dRe.allMatches(s).map((m) => m.group(1)!).toList();
  if (ds.isEmpty) return null;
  final p = ui.Path();
  for (final d in ds) {
    try {
      p.addPath(parseSvgPathData(d), Offset.zero);
    } catch (_) {
      return null;
    }
  }
  return IconSpec(
    f.uri.pathSegments.last.replaceAll('.svg', ''),
    double.parse(vb.group(1)!),
    double.parse(vb.group(2)!),
    p,
  );
}

class Metrics {
  final double bboxCx, bboxCy;
  final double massCx, massCy;
  Metrics(this.bboxCx, this.bboxCy, this.massCx, this.massCy);
}

Future<Metrics> _measure(IconSpec ic, double inner) async {
  final s = inner / math.max(ic.vbW, ic.vbH);
  final tx = (_cell - ic.vbW * s) / 2;
  final ty = (_cell - ic.vbH * s) / 2;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.translate(tx, ty);
  c.scale(s);
  c.drawPath(ic.path, Paint()..color = const Color(0xFFFFFFFF));
  final img = await rec.endRecording().toImage(_cell, _cell);
  final bytes = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final data = bytes.buffer.asUint8List();
  img.dispose();

  int minX = _cell, minY = _cell, maxX = -1, maxY = -1;
  double mxsum = 0, mysum = 0, msum = 0;
  for (int y = 0; y < _cell; y++) {
    for (int x = 0; x < _cell; x++) {
      final a = data[(y * _cell + x) * 4 + 3];
      if (a == 0) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
      final w = a / 255.0;
      mxsum += x * w;
      mysum += y * w;
      msum += w;
    }
  }
  if (maxX < 0) {
    return Metrics(_cell / 2, _cell / 2, _cell / 2, _cell / 2);
  }
  return Metrics(
    (minX + maxX + 1) / 2,
    (minY + maxY + 1) / 2,
    mxsum / msum,
    mysum / msum,
  );
}

enum Strategy { viewBox, bbox, mass }

Future<Uint8List> _renderGrid(
  List<(IconSpec, Metrics)> icons,
  Strategy strat,
) async {
  final w = _cols * _cell;
  final h = _rows * _cell;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = const Color(0xFF101010),
  );

  final inner = _cell - 2 * _padding;
  final cross = Paint()
    ..color = const Color(0x66FF3030)
    ..strokeWidth = 1;
  final border = Paint()
    ..color = const Color(0x33FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final iconPaint = Paint()..color = const Color(0xFFE0E0E0);

  for (int i = 0; i < icons.length && i < _cols * _rows; i++) {
    final (ic, m) = icons[i];
    final col = i % _cols;
    final row = i ~/ _cols;
    final cx = col * _cell.toDouble();
    final cy = row * _cell.toDouble();

    final s = inner / math.max(ic.vbW, ic.vbH);
    final baseTx = (_cell - ic.vbW * s) / 2;
    final baseTy = (_cell - ic.vbH * s) / 2;

    double dx = 0, dy = 0;
    switch (strat) {
      case Strategy.viewBox:
        break;
      case Strategy.bbox:
        dx = _cell / 2 - m.bboxCx;
        dy = _cell / 2 - m.bboxCy;
        break;
      case Strategy.mass:
        dx = _cell / 2 - m.massCx;
        dy = _cell / 2 - m.massCy;
        break;
    }

    c.save();
    c.translate(cx + baseTx + dx, cy + baseTy + dy);
    c.scale(s);
    c.drawPath(ic.path, iconPaint);
    c.restore();

    c.drawLine(
      Offset(cx + _cell / 2, cy),
      Offset(cx + _cell / 2, cy + _cell.toDouble()),
      cross,
    );
    c.drawLine(
      Offset(cx, cy + _cell / 2),
      Offset(cx + _cell.toDouble(), cy + _cell / 2),
      cross,
    );
    c.drawRect(
      Rect.fromLTWH(cx + 0.5, cy + 0.5, _cell - 1.0, _cell - 1.0),
      border,
    );
  }

  final img = await rec.endRecording().toImage(w, h);
  final png = (await img.toByteData(format: ui.ImageByteFormat.png))!;
  img.dispose();
  return png.buffer.asUint8List();
}

void main() {
  test(
    'export centering grids',
    timeout: const Timeout(Duration(minutes: 10)),
    () async {
      Directory(_outDir).createSync(recursive: true);
      final inner = (_cell - 2 * _padding).toDouble();
      final perPage = _cols * _rows;

      for (final style in _styles) {
        final files = Directory('$_svgRoot/$style')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.svg'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

        final measured = <(IconSpec, Metrics)>[];
        for (final f in files) {
          final s = _loadSvg(f);
          if (s == null) continue;
          measured.add((s, await _measure(s, inner)));
        }

        final pages = (measured.length + perPage - 1) ~/ perPage;
        for (final strat in Strategy.values) {
          for (int p = 0; p < pages; p++) {
            final slice = measured.sublist(
              p * perPage,
              math.min((p + 1) * perPage, measured.length),
            );
            final png = await _renderGrid(slice, strat);
            final path =
                '$_outDir/grid_${style}_${strat.name}_${p.toString().padLeft(2, '0')}.png';
            File(path).writeAsBytesSync(png);
            // ignore: avoid_print
            print('wrote $path (${slice.length} icons)');
          }
        }
      }
    },
  );
}
