# glyphs

Optically centered icon glyphs for Flutter, built from Font Awesome Free 7.x.

Standard Font Awesome glyphs are designed inside per-icon viewBoxes that do
not coincide with the glyph's visual center. Dropped into a circular FAB or
square `Icon` slot they often look slightly off-axis. This package solves
that with **per-glyph minimum-enclosing-circle (MEC) center baking**: each
glyph is shifted at font-build time so its MEC center lands at the viewBox
center. The result: every extreme ink point sits on the same circle, so the
glyph is equally distant from any larger concentric container.

`Icon` (Flutter's standard widget) renders glyphs from this font correctly
with no wrapping widget — the centering is part of the font itself.

## Installation

```yaml
dependencies:
  glyphs:
    git:
      url: https://github.com/swipelab/glyphs
```

## Usage

```dart
import 'package:flutter/widgets.dart';
import 'package:glyphs/glyphs.dart';

Icon(GlyphsSolid.anchor, size: 32)
Icon(GlyphsRegular.bell, size: 24)
Icon(GlyphsBrands.github, size: 20)
Icon(GlyphsSymbols.arrow_back_ios_new, size: 24)
```

`find.byIcon`, `IconButton`, `ListTile.leading` and friends all work as
expected — the package doesn't introduce any custom widgets.

## Material Symbols (`GlyphsSymbols`)

`GlyphsSymbols` carries the Material Symbols Rounded glyphs named in
[`tool/symbols.txt`](tool/symbols.txt), under their upstream names. They are
the upstream variable font's default instance: FILL 0, wght 400, GRAD 0,
opsz 24. The font is static, so `Icon`'s `fill`, `weight`, `grade` and
`opticalSize` do not change it.

The family is not MEC-centered. It keeps the upstream placement: the font
uses the upstream 960-unit em and outline coordinates, and each glyph's left
side bearing is its outline's own `xMin`, so a glyph inks where Material
Symbols Rounded inks it on its 24 dp grid.

`tool/extract_symbols.py` writes the SVGs from the upstream
`MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf`, with its `.codepoints` file
beside it (both in `variablefont/` of
[google/material-design-icons](https://github.com/google/material-design-icons)):

```bash
python3 tool/extract_symbols.py '/path/to/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf'
dart run tool/build_font.dart
```

## How the correction is computed

Each glyph is rasterized at 256 px in a 512 px canvas (so heavily-shifted
glyphs don't clip). The ink silhouette is extracted, then **Welzl's
algorithm** computes the minimum enclosing circle. The offset from canvas
center to MEC center is recorded as two em-fractions (`dx`, `dy`).

At font-build time `tool/build_font.py` bakes those offsets into each
glyph: vertical shifts are applied via the path transform, horizontal
shifts via the left side bearing (because Flutter/HarfBuzz re-anchors
single glyphs to `origin + lsb` at render time, so a horizontal path
shift on its own would be discarded).

The full offset table lives at [`assets/offsets.json`](assets/offsets.json)
and is mirrored as Dart constants in `lib/src/glyph_offsets.g.dart` for
inspection — runtime rendering does not consume it.

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
3. Runs `flutter test tool/measure_offsets.dart` to compute the MEC-center
   correction table via Welzl's algorithm.
4. Re-runs the python build with the offsets baked in (pass 2).
5. Regenerates `lib/src/glyphs.g.dart` and `lib/src/glyph_offsets.g.dart`.

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

`GlyphsSymbols` glyphs are derived from **Material Symbols Rounded** by
Google LLC, licensed under the
[Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0). See
[NOTICE.md](NOTICE.md) for the source version and the changes made.

## License

- Code: MIT
- Font Awesome icon artwork (SVGs and compiled glyph outlines): CC BY 4.0
- Material Symbols icon artwork (`assets/svgs/symbols/`,
  `lib/fonts/GlyphsSymbols.ttf`): Apache 2.0

See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
