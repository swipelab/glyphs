#!/usr/bin/env python3
"""Build TTF icon fonts from SVG sources. Invoked by tool/build_font.dart.

Reads a JSON spec on argv[1]:
  {"styles": [{"name", "family", "svgDir", "codepoints": {name: cp}, "outPath"}]}
"""
import json
import re
import sys
from pathlib import Path

try:
    from fontTools.fontBuilder import FontBuilder
    from fontTools.pens.ttGlyphPen import TTGlyphPen
    from fontTools.pens.transformPen import TransformPen
    from fontTools.pens.cu2quPen import Cu2QuPen
    from fontTools.svgLib.path import parse_path
    from fontTools.misc.transform import Transform
except ImportError:
    sys.stderr.write(
        "ERROR: fontTools is not installed.\n"
        "Install with: pip3 install fonttools\n"
    )
    sys.exit(2)

EM = 1000
_VB = re.compile(r'viewBox="0 0 ([\d.]+) ([\d.]+)"')
_D = re.compile(r'\sd="([^"]+)"')


def build_style(style):
    name = style["name"]
    family = style["family"]
    svg_dir = Path(style["svgDir"])
    codepoints = {k: int(v) for k, v in style["codepoints"].items()}
    out_path = Path(style["outPath"])

    fb = FontBuilder(EM, isTTF=True)

    glyph_order = [".notdef"]
    glyphs = {".notdef": TTGlyphPen(None).glyph()}
    advances = {".notdef": EM}
    cmap = {}

    skipped = 0
    for icon_name, cp in sorted(codepoints.items(), key=lambda kv: kv[1]):
        svg_path = svg_dir / f"{icon_name}.svg"
        if not svg_path.exists():
            skipped += 1
            continue
        text = svg_path.read_text()
        m = _VB.search(text)
        if not m:
            skipped += 1
            continue
        vb_w, vb_h = float(m.group(1)), float(m.group(2))
        ds = _D.findall(text)
        if not ds:
            skipped += 1
            continue

        # SVG (y-down) → font (y-up), centered, longest side fits em.
        scale = EM / max(vb_w, vb_h)
        tx = (EM - vb_w * scale) / 2
        ty = (EM - vb_h * scale) / 2
        t = Transform(scale, 0, 0, -scale, tx, EM - ty)

        glyph_name = f"u{cp:04X}"
        pen = TTGlyphPen(None)
        qpen = Cu2QuPen(pen, max_err=1.0)
        tpen = TransformPen(qpen, t)
        try:
            for d in ds:
                parse_path(d, tpen)
        except Exception as e:
            sys.stderr.write(f"  ! {icon_name}: {e}\n")
            skipped += 1
            continue

        glyphs[glyph_name] = pen.glyph()
        glyph_order.append(glyph_name)
        advances[glyph_name] = EM
        cmap[cp] = glyph_name

    fb.setupGlyphOrder(glyph_order)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics({g: (advances[g], 0) for g in glyph_order})
    fb.setupHorizontalHeader(ascent=EM, descent=0)
    fb.setupOS2(sTypoAscender=EM, usWinAscent=EM, usWinDescent=0)
    fb.setupNameTable({"familyName": family, "styleName": "Regular"})
    fb.setupPost()

    out_path.parent.mkdir(parents=True, exist_ok=True)
    fb.font.save(str(out_path))
    print(f"  {name}: wrote {out_path} ({len(cmap)} glyphs, {skipped} skipped)")


def main():
    if len(sys.argv) != 2:
        sys.stderr.write("usage: build_font.py <spec.json>\n")
        sys.exit(2)
    spec = json.loads(Path(sys.argv[1]).read_text())
    for style in spec["styles"]:
        build_style(style)


if __name__ == "__main__":
    main()
