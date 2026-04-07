# Notices and attributions

This package bundles assets derived from third-party work. The following
notices satisfy the attribution requirements of those licenses and **must
remain present in any redistribution** of this package.

## Font Awesome Free

The icons shipped in `assets/svgs/` and the glyph outlines compiled into
`lib/fonts/GlyphsSolid.ttf`, `GlyphsRegular.ttf`, and `GlyphsBrands.ttf`
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

## Trademarks

"Font Awesome" is a trademark of Fonticons, Inc. This package is **not**
affiliated with, endorsed by, or sponsored by Fonticons, Inc. The font
families shipped here are renamed (`Glyphs*`) so as not to imply any such
relationship.
