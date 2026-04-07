// Measures the mass-center offset of each icon glyph relative to its viewBox
// center. Writes assets/offsets.json: { "0xE013": [dx, dy], ... } where (dx,dy)
// are the *correction* to apply (em-fractions) to bring the visual mass to the
// box center. Entries with magnitude below _threshold are skipped.
//
// Run with:
//   flutter test tool/measure_offsets.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_drawing/path_drawing.dart';

const _svgRoot = 'assets/svgs';
const _styles = ['solid', 'regular', 'brands'];
const _cpPath = 'assets/codepoints.json';
const _outPath = 'assets/offsets.json';
const _raster = 256;
const _threshold = 0.002; // ~0.5px at 256 raster — skip "already centered"

final _viewBoxRe = RegExp(r'viewBox="0 0 ([\d.]+) ([\d.]+)"');
final _dRe = RegExp(r'\sd="([^"]+)"');

void main() {
  test(
    'measure mass-center offsets',
    timeout: const Timeout(Duration(minutes: 10)),
    () async {
      final cpJson =
          jsonDecode(File(_cpPath).readAsStringSync())
              as Map<String, dynamic>;
      final result = <String, List<double>>{};

      for (final style in _styles) {
        final cpMap = cpJson[style] as Map<String, dynamic>;
        for (final entry in cpMap.entries) {
          final name = entry.key;
          final cpStr = entry.value as String;
          final f = File('$_svgRoot/$style/$name.svg');
          if (!f.existsSync()) continue;
          final s = f.readAsStringSync();
          final vb = _viewBoxRe.firstMatch(s);
          if (vb == null) continue;
          final vbW = double.parse(vb.group(1)!);
          final vbH = double.parse(vb.group(2)!);
          final ds = _dRe.allMatches(s).map((m) => m.group(1)!).toList();
          if (ds.isEmpty) continue;

          final path = ui.Path();
          try {
            for (final d in ds) {
              path.addPath(parseSvgPathData(d), Offset.zero);
            }
          } catch (_) {
            continue;
          }

          final scale = _raster / math.max(vbW, vbH);
          final tx = (_raster - vbW * scale) / 2;
          final ty = (_raster - vbH * scale) / 2;
          final rec = ui.PictureRecorder();
          final c = Canvas(rec);
          c.translate(tx, ty);
          c.scale(scale);
          c.drawPath(path, Paint()..color = const Color(0xFFFFFFFF));
          final img = await rec.endRecording().toImage(_raster, _raster);
          final bd = (await img.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final data = bd.buffer.asUint8List();
          img.dispose();

          double mxsum = 0, mysum = 0, msum = 0;
          for (int y = 0; y < _raster; y++) {
            for (int x = 0; x < _raster; x++) {
              final a = data[(y * _raster + x) * 4 + 3];
              if (a == 0) continue;
              final w = a / 255.0;
              mxsum += x * w;
              mysum += y * w;
              msum += w;
            }
          }
          if (msum == 0) continue;
          final cx = mxsum / msum;
          final cy = mysum / msum;
          // Correction = (centerOfBox - massCenter), normalized to em.
          final corrX = (_raster / 2 - cx) / _raster;
          final corrY = (_raster / 2 - cy) / _raster;
          if (corrX.abs() < _threshold && corrY.abs() < _threshold) continue;
          result[cpStr] = [
            double.parse(corrX.toStringAsFixed(4)),
            double.parse(corrY.toStringAsFixed(4)),
          ];
        }
      }

      final sorted = Map.fromEntries(
        result.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      );
      File(_outPath).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(sorted),
      );
      // ignore: avoid_print
      print('wrote $_outPath (${sorted.length} entries)');
    },
  );
}
