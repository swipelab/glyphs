## 0.0.1

Initial release.

- Custom TrueType fonts compiled from Font Awesome Free 7.x SVG sources, with
  every glyph re-fit into a 1000-unit em square centered on its viewBox.
- Three font families: `GlyphsSolid`, `GlyphsRegular`, `GlyphsBrands`.
- `Glyph` widget with a `blend` parameter that interpolates between the
  font-native rendering (`0`) and a fully mass-centered rendering (`1`).
- Per-glyph mass-center correction table generated from rasterized SVG
  alpha integrals.
- Deterministic codepoint assignment via FNV-1a + linear probing into
  per-style Private Use Area sub-ranges, checked in at
  `assets/codepoints.json` for diff visibility.
- `dart run tool/build_font.dart` regenerates fonts, metadata, codepoints,
  the offset table, and the Dart constants from the SVG sources.
