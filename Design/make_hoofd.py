"""Menubalk-icoon: het hoofd van de bust, iets groter, zonder nek en schouders. Run: python3 make_hoofd.py"""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import make_wereld20 as w
import make_bust as bust
from make_alternatieven import new, rect, rrect, eyes, VARIANTS

OUT = Path(__file__).parent / "Assets" / "Menubalk-hoofd"; OUT.mkdir(parents=True, exist_ok=True)
RAYS = [(6, 1), (13, 1), (5, 0), (14, 0)]
Z = [(16, 0), (17, 0), (18, 0), (19, 0), (18, 1), (16, 2), (17, 2), (18, 2), (19, 2)]

def head(lit, eye, idle, rays):
    cv = new()
    rect(cv, 9, 4, 2, 1, "K"); rect(cv, 8, 0, 4, 4, "K"); rect(cv, 9, 1, 2, 2, "L" if lit else "K")          # antenne, lampje 2x2
    rrect(cv, 1, 5, 18, 15, "K"); rrect(cv, 2, 6, 16, 13, "B", r=1)                                         # hoofd: contour + grijs
    rect(cv, 0, 10, 1, 5, "K"); rect(cv, 19, 10, 1, 5, "K")                                                 # oorbouten
    rect(cv, 3, 8, 14, 7, "K"); eyes(cv, [(4, 9, 4, 5), (12, 9, 4, 5)], eye)                                 # vizier + ogen
    if idle: rect(cv, 9, 16, 2, 1, "W")
    else: rect(cv, 8, 16, 4, 1, "W"); cv[15][7] = cv[15][12] = "W"                                          # glimlach
    if rays and lit and not idle:
        for x, y in RAYS: cv[y][x] = "s"
    if idle:
        for x, y in Z: cv[y][x] = "z"
    return ["".join(r) for r in cv]

SEQ = [("tracking-1", True, "open", False), ("tracking-2", False, "open", False), ("tracking-3", True, "open", False),
       ("tracking-4", True, "half", False), ("tracking-5", True, "shut", False), ("idle-1", False, "shut", True)]
DUR = {"tracking-1": .5, "tracking-2": .5, "tracking-3": .5, "tracking-4": .08, "tracking-5": .12, "idle-1": .7}
SETS = {"met-stralen": True, "zonder-stralen": False}
FR = {}
for sn, rays in SETS.items():
    d = OUT / sn; d.mkdir(exist_ok=True); FR[sn] = {}
    for name, lit, eye, idle in SEQ:
        g = head(lit, eye, idle, rays); FR[sn][name] = g
        w.mono_png(g, 1).save(d / f"{name}.png"); w.mono_png(g, 2).save(d / f"{name}@2x.png"); (d / f"{name}.svg").write_text(w.svg(g))
    (d / "manifest.json").write_text(json.dumps({"tracking": {"frames": [f"tracking-{i}" for i in range(1, 6)], "durations": [DUR[f"tracking-{i}"] for i in range(1, 6)]}, "idle": {"frames": ["idle-1"]}}, indent=2))

# Preview
SF = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 26); lab = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 18)
rows = {"huidig: bust": {n: bust.FRAMES[n][0] for n, *_ in SEQ},
        "alternatief B (zacht kopje)": {n: VARIANTS["b-zacht-kopje"](lit, eye, idle) for n, lit, eye, idle in SEQ},
        "nieuw: hoofd groter, met stralen": FR["met-stralen"], "nieuw: hoofd groter, zonder stralen": FR["zonder-stralen"]}
RH = 190; sheet = Image.new("RGB", (1380, 40 + RH * len(rows)), "#F8F7F4"); d = ImageDraw.Draw(sheet)
d.text((20, 10), "links: echte grootte @2x in menubalk  |  rechts: alle 6 frames 4x (licht + donker)", fill="#242424", font=lab)
TONES = (((236, 236, 236), (0, 0, 0)), ((38, 38, 38), (255, 255, 255)))
for i, (rn, fr) in enumerate(rows.items()):
    y = 40 + i * RH; d.text((20, y + 2), rn, fill="#242424", font=lab)
    for j, (bg, ink) in enumerate(TONES):
        by = y + 32 + j * 70; d.rectangle([20, by, 350, by + 64], fill=bg)
        for k, fname in enumerate(("tracking-1", "idle-1")):
            im = w.mono_png(fr[fname], 2, ink); sheet.paste(im, (30 + k * 46, by + 12), im)
        d.text((130, by + 18), "Studio Noord 1:42", fill=ink, font=SF)
        for k, (name, *_) in enumerate(SEQ):
            x = 390 + k * 160; d.rectangle([x, by, x + 148, by + 64], fill=bg)
            im = w.mono_png(fr[name], 3, ink); sheet.paste(im, (x + 44, by + 2), im)
sheet.save(OUT / "hoofd.png"); print("ok")
