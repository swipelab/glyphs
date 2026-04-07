# glyphs

Optically centered icon glyphs for Flutter, built from Font Awesome Free 7.x.

The standard Font Awesome glyphs are designed inside per-icon viewBoxes that
do not always coincide with the glyph's visual center of mass. When dropped
into a square `Icon` slot they often look slightly off-axis. This package
solves that two ways:

1. **A custom TrueType font per Font Awesome style** — `GlyphsSolid`,
   `GlyphsRegular`, `GlyphsBrands` — with every glyph re-fit into a 1000-unit
   em square, centered on its viewBox.
2. **A `Glyph` widget** that can additionally shift the rendered icon toward
   its **mass center** at draw time, using a per-glyph correction table baked
   from the source SVGs. The shift is interpolated by a `blend` parameter so
   you can pick the amount of correction per call site.

## Installation

```yaml
dependencies:
  glyphs:
    git:
      url: https://github.com/swipelab/glyphs
```

## Usage

```dart
import 'package:glyphs/glyphs.dart';

// blend = 0  → font-native (viewBox center, identical to a regular Icon)
// blend = 1  → fully mass-centered
// values in between linearly interpolate the correction.
Glyph(GlyphsSolid.anchor, size: 32, blend: 1.0)
Glyph(GlyphsRegular.bell, size: 24, blend: 0.5)
Glyph(GlyphsBrands.github, size: 20)
```

`Glyph` extends `StatelessWidget` and renders a regular Flutter `Icon`
internally, so `find.byIcon`, `IconButton`, `ListTile.leading` and friends
all work as expected. The optical correction is applied via a single
`Transform.translate`.

## How the correction is computed

Each SVG is rasterized at 256×256, the alpha channel is integrated to find
the visual mass centroid, and the offset from the box center is recorded as
two `em`-fractions (`dx`, `dy`). At paint time the `Glyph` widget shifts the
icon by `Offset(dx * blend * size, dy * blend * size)`. Entries with a
correction below ~0.5px are skipped.

The full table lives at [`assets/offsets.json`](assets/offsets.json) and is
mirrored as Dart constants in `lib/src/glyph_offsets.g.dart`.

## Rebuilding the font

The fonts, codepoint tables, and Dart constants are all generated. Run:

```bash
dart run tool/build_font.dart
```

The build:

1. Hashes each icon name into a per-style PUA sub-range (FNV-1a + linear
   probing). The result is deterministic across machines.
2. Calls `tool/build_font.py` (uses `fontTools`) to compile each style into
   a TTF, converting cubic outlines to quadratics.
3. Runs `flutter test tool/measure_offsets.dart` to compute the mass-center
   correction table.
4. Regenerates `lib/src/glyphs.g.dart` and `lib/src/glyph_offsets.g.dart`.

### System requirements

- Dart / Flutter SDK
- Python 3 with [fontTools](https://github.com/fonttools/fonttools)
  ```bash
  brew install python      # macOS, if needed
  pip3 install fonttools
  ```

The build script verifies both at startup and prints install instructions if
either is missing.

## Codepoint stability

Codepoints are derived from `FNV-1a(name) mod range`, with linear probing on
collision. The full assignment is checked in at
[`assets/codepoints.json`](assets/codepoints.json) so any drift caused by
adding or removing icons is visible in code review.

## Attribution

Icons are derived from **Font Awesome Free** by Fonticons, Inc., licensed
under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). See
[NOTICE.md](NOTICE.md) for the full attribution and the list of changes
made.

This package is not affiliated with, endorsed by, or sponsored by Fonticons,
Inc.

## License

- Code: MIT
- Icon artwork (SVGs and compiled glyph outlines): CC BY 4.0

See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
