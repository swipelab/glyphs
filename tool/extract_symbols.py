#!/usr/bin/env python3
"""Extracts the Material Symbols Rounded glyphs named in tool/symbols.txt as
SVG files.

Pins the upstream variable font to FILL 0, GRAD 0, opsz 24 and wght 400, and
writes one outline per name into assets/svgs/symbols/<name>.svg, replacing
the SVGs already there. Run from the glyphs project root:

    python3 tool/extract_symbols.py '/path/to/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf'

The upstream `.codepoints` file beside the font maps each name to its
codepoint.
"""

import sys
from pathlib import Path

try:
    from fontTools.ttLib import TTFont
    from fontTools.varLib import instancer
    from fontTools.pens.svgPathPen import SVGPathPen
    from fontTools.pens.transformPen import TransformPen
    from fontTools.misc.transform import Transform
except ImportError:
    sys.stderr.write(
        "ERROR: fontTools is not installed.\n"
        "Install with: pip3 install fonttools\n"
    )
    sys.exit(2)

AXES = {"FILL": 0, "GRAD": 0, "opsz": 24, "wght": 400}
NAMES = Path("tool/symbols.txt")
OUT_DIR = Path("assets/svgs/symbols")


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit("usage: extract_symbols.py <MaterialSymbolsRounded[...].ttf>")
    ttf = Path(sys.argv[1]).expanduser()
    codepoints_path = ttf.with_suffix(".codepoints")
    for p in (ttf, codepoints_path):
        if not p.exists():
            sys.exit(f"ERROR: {p} not found")

    codepoints = {}
    for line in codepoints_path.read_text().splitlines():
        name, cp = line.split()
        codepoints[name] = int(cp, 16)
    names = NAMES.read_text().split()
    missing = [n for n in names if n not in codepoints]
    if missing:
        sys.exit(f"ERROR: not in {codepoints_path.name}: {' '.join(missing)}")

    print(f"Reading {ttf}")
    font = instancer.instantiateVariableFont(TTFont(str(ttf)), AXES)
    cmap = font.getBestCmap()
    glyph_set = font.getGlyphSet()
    upem = font["head"].unitsPerEm

    # Font coordinates are y-up; the glyphs build reads y-down SVGs whose
    # viewBox is the em square.
    flip = Transform(1, 0, 0, -1, 0, upem)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for stale in OUT_DIR.glob("*.svg"):
        stale.unlink()
    for name in names:
        pen = SVGPathPen(glyph_set)
        glyph_set[cmap[codepoints[name]]].draw(TransformPen(pen, flip))
        svg = (
            f'<svg xmlns="http://www.w3.org/2000/svg" '
            f'viewBox="0 0 {upem} {upem}">'
            f'<path fill="currentColor" d="{pen.getCommands()}"/></svg>\n'
        )
        (OUT_DIR / f"{name}.svg").write_text(svg)
    print(f"wrote {len(names)} SVGs to {OUT_DIR}")


if __name__ == "__main__":
    main()
