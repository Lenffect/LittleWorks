"""Testen van mono-regels voor de figuren. Run: python3 mono_test.py"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import make_figuren as m

OUT = Path(__file__).parent / "Tikk" / "figuren"
def lum(h): r, g, b = (int(h[i:i+2], 16) for i in (1, 3, 5)); return (0.299*r + 0.587*g + 0.114*b) / 255
def rule_A(g):  # contour + ogen
    return [[c == "K" for c in r] for r in g]
def rule_B(g, t=0.62):  # donkere tinten zwart, lichte tinten gat
    return [[c != "." and (c == "K" or lum(m.P[c]) < t) for c in r] for r in g]
def rule_C(g):  # massief silhouet, binnenlijnen/ogen uitgesneden
    out = []
    for y, r in enumerate(g):
        row = []
        for x, c in enumerate(r):
            if c == ".": row.append(False); continue
            if c != "K": row.append(True); continue
            nb = [(x+1, y), (x-1, y), (x, y+1), (x, y-1)]
            outer = any(not (0 <= a < 16 and 0 <= b < 16) or g[b][a] == "." for a, b in nb)
            row.append(outer)
        out.append(row)
    return out

def render(mask, scale, ink):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y, r in enumerate(mask):
        for x, v in enumerate(r):
            if v: im.putpixel((x, y), ink)
    return im.resize((16*scale, 16*scale), Image.NEAREST)

if __name__ == "__main__":
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)
    S = 5; cw = 16*S + 14
    names = list(m.F)
    sheet = Image.new("RGB", (len(names)*cw + 120, 4*(16*S+14) + 20), "#F8F7F4"); d = ImageDraw.Draw(sheet)
    rows = [("kleur", None), ("A contour", rule_A), ("B tint", rule_B), ("C massief+gaten", rule_C)]
    for j, (lab, rule) in enumerate(rows):
        y = 10 + j*(16*S+14); d.text((6, y+30), lab, fill="#242424", font=font)
        for i, n in enumerate(names):
            im = m.png(m.F[n], S) if rule is None else render(rule(m.F[n]), S, (0, 0, 0, 255))
            sheet.paste(im, (120 + i*cw, y), im)
    sheet.save(OUT / "mono_test.png"); print("ok")
