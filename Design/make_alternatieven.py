"""Alternatieven voor het menubalk-icoon (rustiger dan de bust). Run: python3 make_alternatieven.py"""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import make_wereld20 as w
import make_bust as bust

OUT = Path(__file__).parent / "Assets" / "Menubalk-alternatieven"; OUT.mkdir(parents=True, exist_ok=True)
N = 20
def new(): return [["."] * N for _ in range(N)]
def rect(cv, x, y, wd, ht, ch):
    for yy in range(y, y + ht):
        for xx in range(x, x + wd): cv[yy][xx] = ch
def rrect(cv, x, y, wd, ht, ch, r=2):
    rect(cv, x, y, wd, ht, ch)
    cuts = {1: [(0, 0)], 2: [(0, 0), (1, 0), (0, 1)]}[r]
    for dx, dy in cuts:
        for px, py in ((x + dx, y + dy), (x + wd - 1 - dx, y + dy), (x + dx, y + ht - 1 - dy), (x + wd - 1 - dx, y + ht - 1 - dy)): cv[py][px] = "."
def eyes(cv, rects, state, ch="E"):
    for x, y, wd, ht in rects:
        if state == "open": rect(cv, x, y, wd, ht, ch)
        elif state == "half": rect(cv, x, y + ht // 2 - 1, wd, 2, ch)
        else: rect(cv, x, y + ht // 2, wd, 1, "e")
def antenna(cv, lit, stem_h):
    rect(cv, 9, 4, 2, 1, "K"); rect(cv, 8, 0, 4, 4, "K"); rect(cv, 9, 1, 2, 2, "L" if lit else "K")   # lampje 2x2: pulst beter zichtbaar
def finish(cv, idle):
    if idle:
        for x, y in ((16, 0), (17, 0), (18, 0), (19, 0), (18, 1), (16, 2), (17, 2), (18, 2), (19, 2)): cv[y][x] = "z"
    return ["".join(r) for r in cv]

def variant_a(lit, eye, idle):      # vet kopje: massief zwart, gaten
    cv = new(); antenna(cv, lit, 2); rrect(cv, 2, 5, 16, 14, "K"); rect(cv, 0, 10, 2, 4, "K"); rect(cv, 18, 10, 2, 4, "K")
    eyes(cv, [(4, 8, 4, 4), (12, 8, 4, 4)], eye)
    rect(cv, 9 if idle else 8, 15, 2 if idle else 4, 1, "W")
    if not idle: cv[14][7] = cv[14][12] = "W"
    return finish(cv, idle)
def variant_b(lit, eye, idle):      # zacht kopje: grijs met zwart vizier
    cv = new(); antenna(cv, lit, 2); rect(cv, 2, 5, 16, 14, "K"); rect(cv, 3, 6, 14, 12, "B"); rect(cv, 0, 10, 2, 4, "K"); rect(cv, 18, 10, 2, 4, "K")
    rect(cv, 4, 7, 12, 7, "K"); eyes(cv, [(5, 8, 3, 4), (12, 8, 3, 4)], eye)
    rect(cv, 9 if idle else 8, 15, 2 if idle else 4, 1, "W")
    return finish(cv, idle)
def variant_c(lit, eye, idle):      # monitor-robot: alleen scherm met ogen + voetje
    cv = new(); antenna(cv, lit, 2); rrect(cv, 1, 5, 18, 12, "K"); rect(cv, 8, 17, 4, 1, "K"); rect(cv, 5, 18, 10, 2, "K")
    eyes(cv, [(4, 7, 4, 5), (12, 7, 4, 5)], eye)
    return finish(cv, idle)
def variant_d(lit, eye, idle):      # rond kopje
    cv = new(); antenna(cv, lit, 2)
    for yy in range(N):
        for xx in range(N):
            if (xx + 0.5 - 10) ** 2 + (yy + 0.5 - 12) ** 2 <= 7.9 ** 2: cv[yy][xx] = "K"
    eyes(cv, [(5, 9, 3, 4), (12, 9, 3, 4)], eye)
    rect(cv, 9 if idle else 8, 16, 2 if idle else 4, 1, "W")
    if not idle: cv[15][7] = cv[15][12] = "W"
    return finish(cv, idle)
def variant_e(lit, eye, idle):      # cyclops: één groot oog met pupil
    cv = new(); antenna(cv, lit, 2); rrect(cv, 2, 5, 16, 14, "K"); rect(cv, 0, 10, 2, 4, "K"); rect(cv, 18, 10, 2, 4, "K")
    eyes(cv, [(6, 8, 8, 6)], eye)
    if eye == "open": rect(cv, 9, 9, 2, 4, "K")
    rect(cv, 8, 16, 4, 1, "W") if not idle else rect(cv, 9, 16, 2, 1, "W")
    return finish(cv, idle)

VARIANTS = {"a-vet-kopje": variant_a, "b-zacht-kopje": variant_b, "c-monitor": variant_c, "d-rond": variant_d, "e-cyclops": variant_e}
SEQ = [("tracking-1", True, "open", False, 0.5), ("tracking-2", False, "open", False, 0.5), ("tracking-3", True, "open", False, 0.5),
       ("tracking-4", True, "half", False, 0.08), ("tracking-5", True, "shut", False, 0.12), ("idle-1", False, "shut", True, 0.7)]
FR = {}
for vn, fn in VARIANTS.items():
    d = OUT / vn; d.mkdir(exist_ok=True); FR[vn] = {}
    for name, lit, eye, idle, _ in SEQ:
        g = fn(lit, eye, idle); FR[vn][name] = g
        w.mono_png(g, 1).save(d / f"{name}.png"); w.mono_png(g, 2).save(d / f"{name}@2x.png"); (d / f"{name}.svg").write_text(w.svg(g))
FR = {"huidig: bust": {n: bust.FRAMES[n if n != "idle-1" else "idle-1"][0] for n, *_ in SEQ}, **FR}

# Preview
SF = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 26); lab = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 18)
rows = list(FR); RH = 128; W_, H_ = 1500, 40 + RH * len(rows)
sheet = Image.new("RGB", (W_, H_), "#F8F7F4"); d = ImageDraw.Draw(sheet)
d.text((20, 10), "echte grootte @2x in menubalk (licht/donker)  |  alle frames 4x: lampje, knipper, slapen", fill="#242424", font=lab)
for i, vn in enumerate(rows):
    y = 40 + i * RH; d.text((20, y + 4), vn, fill="#242424", font=lab)
    for j, (bg, ink) in enumerate(((  (236, 236, 236), (0, 0, 0)), ((38, 38, 38), (255, 255, 255)))):
        by = y + 30 + j * 48 + (0)
        d.rectangle([20, by, 340, by + 44], fill=bg)
        for k, fname in enumerate(("tracking-1", "idle-1")):
            im = w.mono_png(FR[vn][fname], 2, ink); sheet.paste(im, (28 + k * 44, by + 2), im)
        d.text((120, by + 6), "Studio Noord 1:42", fill=ink, font=SF)
    for k, (name, *_) in enumerate(SEQ):
        for j, (bg, ink) in enumerate(((  (236, 236, 236), (0, 0, 0)), ((38, 38, 38), (255, 255, 255)))):
            x = 360 + k * 188 + 0; by = y + 4 + j * 0
            d.rectangle([x, y + 2 + j * 62, x + 90, y + 62 + j * 62 - 4 if False else y + 62 + j * 62 - 4], fill=bg) if False else None
        # twee blokjes boven elkaar per frame: licht/donker, 3x
        for j, (bg, ink) in enumerate(((  (236, 236, 236), (0, 0, 0)), ((38, 38, 38), (255, 255, 255)))):
            x = 360 + k * 190; yy = y + 2 + j * 60
            d.rectangle([x, yy, x + 76, yy + 56], fill=bg)
            im = w.mono_png(FR[vn][name], 2, ink).resize((54, 54), Image.NEAREST) if False else w.mono_png(FR[vn][name], 3, ink)
            sheet.paste(im.crop((0, 0, 60, 54)).resize((60, 54)) if False else im.resize((54, 54), Image.NEAREST), (x + 11, yy + 1), im.resize((54, 54), Image.NEAREST))
sheet.save(OUT / "alternatieven.png"); print("ok")
