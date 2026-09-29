# Notices and attributions

This package bundles assets derived from third-party work. The following
notices satisfy the attribution requirements of those licenses and **must
remain present in any redistribution** of this package.

## Font Awesome Free

The icons shipped in `assets/svgs/solid/`, `assets/svgs/regular/` and
`assets/svgs/brands/`, and the glyph outlines compiled into
`lib/fonts/GlyphsSolid.ttf`, `GlyphsRegular.ttf`, and `GlyphsBrands.ttf`,
are derived from **Font Awesome Free 7.x** by **Fonticons, Inc.**

- Project: https://fontawesome.com
- License: Creative Commons Attribution 4.0 International (CC BY 4.0)
  https://creativecommons.org/licenses/by/4.0/
- Upstream license terms: https://fontawesome.com/license/free

### What was changed

The SVG path data is unmodified from the upstream Font Awesome Free 7.x
release. The glyphs are repackaged into a custom TrueType font with:

- Per-style font families (`GlyphsSolid`, `GlyphsRegular`, `GlyphsBrands`).
- Codepoints reassigned via FNV-1a hashing into the Unicode Private Use
  Area (`U+E000`–`U+F8FF`); see `assets/codepoints.json`.
- Outlines re-fitted into a 1000-unit em square, centered on each glyph's
  viewBox, and converted from cubic to quadratic Béziers.

The original Font Awesome OTF files are **not** redistributed. Only glyph
geometry derived from the publicly licensed CC BY 4.0 SVG sources is
included.

### Required attribution

When redistributing this package, or any derivative font built from it,
include a visible acknowledgment such as:

> Icons by Font Awesome (https://fontawesome.com), licensed under
> CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).

## Custom glyphs (`GlyphsCustom`)

The four glyphs under `assets/svgs/custom/` (`tool_pen`, `tool_marker`,
`tool_neon`, `tool_eraser`) are original SVG silhouettes drawn for this
package. They are **not** derived from Font Awesome or any third-party
icon set. Licensed alongside the package source under MIT.

## Material Symbols (`GlyphsSymbols`)

The glyphs under `assets/svgs/symbols/` and the glyph outlines compiled into
`lib/fonts/GlyphsSymbols.ttf` are derived from **Material Symbols Rounded**
(Version 2.972) by **Google LLC**: the font
`variablefont/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf` of
https://github.com/google/material-design-icons at commit `bd8cb85`.

- Copyright 2026 Google LLC. All Rights Reserved.
- License: Apache License, Version 2.0 (full text in [LICENSE](LICENSE))
  https://www.apache.org/licenses/LICENSE-2.0

### What was changed

- The variable font is instanced at its default location — FILL 0, GRAD 0,
  opsz 24, wght 400 — and the glyphs named in `tool/symbols.txt` are
  extracted as SVG outlines (`tool/extract_symbols.py`).
- The outlines are repackaged into the static TrueType font `GlyphsSymbols`
  with the upstream 960-unit em, advance widths and left side bearings.
  Implied on-curve points are written out explicitly, rounded to whole
  units.
- Codepoints are reassigned via FNV-1a hashing into the Unicode Private Use
  Area; see `assets/codepoints.json`. The upstream variation axes,
  ligatures and hinting tables are not carried over.

The upstream font files are **not** redistributed. This package is **not**
affiliated with, endorsed by, or sponsored by Google LLC.

## Trademarks

"Font Awesome" is a trademark of Fonticons, Inc. This package is **not**
affiliated with, endorsed by, or sponsored by Fonticons, Inc. The font
families shipped here are renamed (`Glyphs*`) so as not to imply any such
relationship.
