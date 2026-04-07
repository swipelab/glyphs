import 'package:flutter/widgets.dart';

import 'glyph_offsets.g.dart';

/// Renders a glyph with adjustable optical centering.
///
/// `blend` interpolates between the font's native viewBox-centered rendering
/// (`0`) and a fully mass-centered rendering (`1`). Values in between linearly
/// interpolate the correction. The correction is per-glyph, looked up from the
/// generated [kGlyphMassDelta] table.
class Glyph extends StatelessWidget {
  final IconData glyph;
  final double size;

  /// 0 = viewBox center (font native), 1 = mass center.
  final double blend;
  final Color? color;

  const Glyph(
    this.glyph, {
    this.size = 24,
    this.blend = 0,
    this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final d = kGlyphMassDelta[glyph.codePoint];
    if (d == null || blend == 0) {
      return Icon(glyph, size: size, color: color);
    }
    return Transform.translate(
      offset: Offset(d.dx * blend * size, d.dy * blend * size),
      child: Icon(glyph, size: size, color: color),
    );
  }
}
