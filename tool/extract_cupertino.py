#!/usr/bin/env python3
"""Extracts individual glyphs from CupertinoIcons.ttf as SVG files.

Outputs one SVG per requested glyph into assets/svgs/cupertino/.
Run from the glyphs project root:

    python3 tool/extract_cupertino.py /path/to/CupertinoIcons.ttf

The path is optional; by default the script looks in the pub cache.
"""

import sys
from pathlib import Path

try:
    from fontTools.ttLib import TTFont
    from fontTools.pens.svgPathPen import SVGPathPen
    from fontTools.pens.transformPen import TransformPen
    from fontTools.misc.transform import Transform
except ImportError:
    sys.stderr.write(
        "ERROR: fontTools is not installed.\n"
        "Install with: pip3 install fonttools\n"
    )
    sys.exit(2)

# name (as it will appear in assets/svgs/cupertino/<name>.svg) → codepoint
ICONS = {
    "clock": 0xF4BE,
    "checkmark-alt": 0xF8C1,
    "pencil": 0xF37E,
    "exclamationmark-triangle-fill": 0xF661,
}

DEFAULT_TTF_SEARCH = [
    Path.home()
    / ".pub-cache/hosted/pub.dev/cupertino_icons-1.0.8/assets/CupertinoIcons.ttf",
    Path.home()
    / ".pub-cache/hosted/pub.flutter-io.cn/cupertino_icons-1.0.8/assets/CupertinoIcons.ttf",
]


def locate_font(arg: str | None) -> Path:
    if arg:
        p = Path(arg).expanduser()
        if not p.exists():
            sys.exit(f"ERROR: {p} not found")
        return p
    for candidate in DEFAULT_TTF_SEARCH:
        if candidate.exists():
            return candidate
    sys.exit(
        "ERROR: CupertinoIcons.ttf not found. Pass the path as an argument, "
        "or run `flutter pub get` in a project that depends on cupertino_icons."
    )


def main() -> None:
    ttf = locate_font(sys.argv[1] if len(sys.argv) > 1 else None)
    print(f"Reading {ttf}")

    font = TTFont(str(ttf))
    cmap = font.getBestCmap()
    glyph_set = font.getGlyphSet()
    upem = font["head"].unitsPerEm

    out_dir = Path("assets/svgs/cupertino")
    out_dir.mkdir(parents=True, exist_ok=True)

    # Font coordinates are y-up; SVGs (and the glyphs build pipeline) expect
    # y-down. Pre-apply the flip during extraction so the resulting SVG is a
    # plain <path d="..."/> that renders right-side-up in a browser and is
    # consumed verbatim by tool/build_font.py.
    flip = Transform(1, 0, 0, -1, 0, upem)

    for name, cp in ICONS.items():
        glyph_name = cmap.get(cp)
        if glyph_name is None:
            print(f"skip {name}: U+{cp:04X} missing from cmap")
            continue
        pen = SVGPathPen(glyph_set)
        glyph_set[glyph_name].draw(TransformPen(pen, flip))
        path_d = pen.getCommands().strip()
        if not path_d:
            print(f"skip {name}: empty path")
            continue
        svg = (
            f'<svg xmlns="http://www.w3.org/2000/svg" '
            f'viewBox="0 0 {upem} {upem}">'
            f'<path fill="currentColor" d="{path_d}"/></svg>\n'
        )
        target = out_dir / f"{name}.svg"
        target.write_text(svg)
        print(f"wrote {target}")


if __name__ == "__main__":
    main()
