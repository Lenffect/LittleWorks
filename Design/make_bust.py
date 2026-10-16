"""Menubalk-versie: kop en schouders (bust), 20x20, animaties. Run: python3 make_bust.py"""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import make_wereld20 as w

OUT = Path(__file__).parent / "Assets" / "Menubalk-bust"; OUT.mkdir(parents=True, exist_ok=True)
TOP = dict(lit=("........KK", "........KL", ".........K"), off=("........KK", "........KK", ".........K"),
           sleep=("..........", "..........", ".........K"))
EYE_OPEN = [".KBKEEEEKK"] * 4
EYE_HALF = [".KBKKKKKKK", ".KBKEEEEKK", ".KBKEEEEKK", ".KBKKKKKKK"]
EYE_SHUT = [".KBKKKKKKK", ".KBKKKKKKK", ".KBKeeeeKK", ".KBKKKKKKK"]
CHIN_SMILE = (".KBBBBBWBB", ".KBBBBBBWW"); CHIN_SLEEP = (".KBBBBBBBB", ".KBBBBBBBW")
CHEST_LIT = (".KBBBBBBWW", ".KBBBBBBWL"); CHEST_OFF = (".KBBBBBBWW", ".KBBBBBBWK")

def bust(top, eyes, chin, chest):
    rows = [*top, "...KKKKKKK", "..KKBBBBBB", ".KBBBBBBBB", ".KBKKKKKKK", *eyes, ".KBKKKKKKK", chin[0], chin[1], "..KKBBBBBB",
            "...KKKKKKK", ".KKBBBBBBB", *chest, ".KKKKKKKKK"]
    assert len(rows) == 20 and all(len(r) == 10 for r in rows), [len(r) for r in rows]
    return [r + r[::-1] for r in rows]
RAYS = [(6, 1), (13, 1), (5, 0), (14, 0)]
def zshape(y0): return [(16, y0), (17, y0), (18, y0), (19, y0), (18, y0 + 1), (16, y0 + 2), (17, y0 + 2), (18, y0 + 2), (19, y0 + 2)]
def droop(g): return w.put(g, [(10, 1), (11, 1), (12, 1), (12, 2)], "K")

lit = lambda eyes: w.put(bust(TOP["lit"], eyes, CHIN_SMILE, CHEST_LIT), RAYS, "s")
FRAMES = {
 "tracking-1": (lit(EYE_OPEN), 0.5),
 "tracking-2": (bust(TOP["off"], EYE_OPEN, CHIN_SMILE, CHEST_OFF), 0.5),
 "tracking-3": (lit(EYE_OPEN), 0.5),
 "tracking-4": (lit(EYE_HALF), 0.08),
 "tracking-5": (lit(EYE_SHUT), 0.12),
 "idle-1": (w.put(droop(bust(TOP["sleep"], EYE_SHUT, CHIN_SLEEP, CHEST_OFF)), zshape(1), "z"), 0.7),
 "idle-2": (w.put(droop(bust(TOP["sleep"], EYE_SHUT, CHIN_SLEEP, CHEST_OFF)), zshape(0), "z"), 0.7),
 "idle-3": (droop(bust(TOP["sleep"], EYE_SHUT, CHIN_SLEEP, CHEST_OFF)), 0.7),
}
PAL = {**w.BASE, **w.pal("#9A9A9A", "#5FD6E0")}
for n, (g, _) in FRAMES.items():
    (OUT / f"{n}.svg").write_text(w.svg(g, PAL)); (OUT / f"{n}-mono.svg").write_text(w.svg(g))
    w.mono_png(g, 1).save(OUT / f"{n}.png"); w.mono_png(g, 2).save(OUT / f"{n}@2x.png"); w.color_png(g, PAL, 16).save(OUT / f"{n}-kleur.png")
(OUT / "manifest.json").write_text(json.dumps({
    "tracking": {"frames": [f"tracking-{i}" for i in range(1, 6)], "durations": [FRAMES[f"tracking-{i}"][1] for i in range(1, 6)], "loop": True},
    "idle": {"frames": [f"idle-{i}" for i in range(1, 4)], "durations": [0.7] * 3, "loop": True},
    "opmerking": "Template-images (zwart + 50% alpha), 20x20 pt. Animatie alleen bij lopende timer; uit bij Reduce Motion (toon dan tracking-1 / idle-3)."}, indent=2))
def gif(names, fn, scale=14):
    fr = [Image.alpha_composite(Image.new("RGBA", (20 * scale,) * 2, "#F8F7F4"), w.color_png(FRAMES[n][0], PAL, scale)).convert("P") for n in names]
    fr[0].save(OUT / fn, save_all=True, append_images=fr[1:], duration=[int(FRAMES[n][1] * 1000) for n in names], loop=0)
gif([f"tracking-{i}" for i in range(1, 6)], "tracking.gif"); gif([f"idle-{i}" for i in range(1, 4)], "idle.gif")

# ---- Preview: vergelijking oud (volledig lijf) vs nieuw (bust) in een nagebouwde menubalk, @2x ----
SF = lambda s: ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", s)
fnt = SF(26); small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 18)
old = {"tracking": w.FIG["tikk-werk-a"][0], "idle": w.FIG["tikk-slaap"][0]}
W, H = 1180, 560
sheet = Image.new("RGB", (W, H), "#F8F7F4"); d = ImageDraw.Draw(sheet)
def bar(y, dark, items):
    bg, ink = ((38, 38, 38), (255, 255, 255)) if dark else ((236, 236, 236), (0, 0, 0))
    d.rectangle([0, y, W, y + 48], fill=bg); x = 24
    for g, label, tail in items:
        im = w.mono_png(g, 2, ink); sheet.paste(im, (x, y + 4), im); x += 44
        if label: d.text((x, y + 9), label, fill=ink, font=fnt); x += int(d.textlength(label, font=fnt)) + 8
        for t in ("", ):
            pass
        x += 56
for j, dark in enumerate((False, True)):
    y = 40 + j * 120
    d.text((24, y - 28), "oud (volledig lijf)  |  nieuw (bust) — echte grootte @2x", fill="#242424", font=small) if j == 0 else None
    bar(y, dark, [(old["tracking"], "Studio Noord  1:42", ""), (FRAMES["tracking-1"][0], "Studio Noord  1:42", ""), (old["idle"], "", ""), (FRAMES["idle-1"][0], "", "")])
# alle frames uitvergroot
y0 = 300
for i, n in enumerate(FRAMES):
    x = 20 + (i % 8) * 142
    for j, (bgc, ink) in enumerate(((  (236, 236, 236), (0, 0, 0)), ((38, 38, 38), (255, 255, 255)))):
        yy = y0 + j * 125; d.rectangle([x - 4, yy, x + 134, yy + 118], fill=bgc)
        im = w.mono_png(FRAMES[n][0], 5, ink); sheet.paste(im, (x + 14, yy + 9), im)
    d.text((x, y0 + 252), n, fill="#242424", font=ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 15))
sheet.save(OUT / "bust-vergelijking.png"); print("ok")
