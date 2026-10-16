"""Menubalk-versies (template, zwart + alpha) van de figuren. Regel: donkere tinten zwart, lichte tinten gat. Run: python3 make_mono.py"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import make_figuren as m
from mono_test import rule_B, render

OUT = Path(__file__).parent / "Tikk" / "figuren" / "mono"; OUT.mkdir(parents=True, exist_ok=True)

def mono_svg(mask):
    rects = []
    for y, r in enumerate(mask):
        x = 0
        while x < 16:
            if not r[x]: x += 1; continue
            x2 = x
            while x2 + 1 < 16 and r[x2 + 1]: x2 += 1
            rects.append(f'<rect x="{x+1}" y="{y+1}" width="{x2-x+1}" height="1"/>')   # +1: marge voor 18x18 canvas
            x = x2 + 1
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 18 18" width="18" height="18" shape-rendering="crispEdges" fill="#000">\n'
            + "\n".join(rects) + "\n</svg>\n")

def tpl(mask, scale):   # 18x18 pt canvas, 1 px marge
    im = Image.new("RGBA", (18, 18), (0, 0, 0, 0)); im.paste(render(mask, 1, (0, 0, 0, 255)), (1, 1))
    return im.resize((18 * scale, 18 * scale), Image.NEAREST)

masks = {n: rule_B(g) for n, g in m.F.items()}
for n, mk in masks.items():
    slug = n.split()[0] + "-" + n.split()[1]
    (OUT / f"{slug}.svg").write_text(mono_svg(mk))
    tpl(mk, 1).save(OUT / f"{slug}.png"); tpl(mk, 2).save(OUT / f"{slug}@2x.png")

# Preview: echte 18 px (@1x) en 36 px (@2x), licht en donker, plus 6x uitvergroot
font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 15)
cw = 150; W = len(masks) * cw + 40
sheet = Image.new("RGB", (W, 2 * 150 + 20), "#F8F7F4"); d = ImageDraw.Draw(sheet)
for j, (bg, ink) in enumerate([("#F8F7F4", (0, 0, 0, 255)), ("#242424", (255, 255, 255, 255))]):
    y = 10 + j * 150; d.rectangle([10, y, W - 10, y + 138], fill=bg)
    for i, (n, mk) in enumerate(masks.items()):
        x = 24 + i * cw
        for im, ox in ((tpl(mk, 1), 0), (tpl(mk, 2), 26)):
            im = Image.merge("RGBA", (*[Image.new("L", im.size, ink[0])] * 3, im.split()[3]))
            sheet.paste(im, (x + ox, y + 14), im)
        big = Image.merge("RGBA", (*[Image.new("L", (108, 108), ink[0])] * 3, tpl(mk, 6).split()[3]))
        sheet.paste(big, (x, y + 40 - 0), big)
        d.text((x + 70, y + 16), n.split()[1], fill="#fff" if ink[0] else "#242424", font=font)
sheet.save(OUT / "mono.png"); print("ok", len(masks))
