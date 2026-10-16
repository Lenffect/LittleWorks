"""Alle overige assets van de lijst: poses, app-iconen, woordmerken, onboarding, palet, delen. Run: python3 make_assets.py"""
import json, shutil
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops
import make_wereld20 as w

ROOT = Path(__file__).parent / "Assets"
for sub in ("Menubalk", "Tikk", "AppIcon", "Woordmerk", "Onboarding", "Palet", "Delen"): (ROOT / sub).mkdir(parents=True, exist_ok=True)
INK, CREAM, ORANGE, GREEN, BLUE = "#242424", "#F8F7F4", "#FF8A4C", "#91B89A", "#7FA3C7"
hx = lambda h: tuple(int(h[i:i+2], 16) for i in (1, 3, 5))
BASE = {**w.BASE, "g": "#D9D9D9", "o": ORANGE, "n": GREEN, "u": BLUE, "y": "#F2C14E", "q": "#FFE3D2", "r": "#E88FA3", "x": "#9A9A9A", "l": "#D9D9D9"}

def render(g, pal, sc, bg=None):
    h, wd = len(g), len(g[0]); im = Image.new("RGBA", (wd, h), bg or (0, 0, 0, 0))
    for y, r in enumerate(g):
        for x, c in enumerate(r):
            if c != ".": im.putpixel((x, y), hx(pal[c]) + (255,))
    return im.resize((wd * sc, h * sc), Image.NEAREST)
def svg(g, pal, name):
    out = []
    for y, r in enumerate(g):
        x = 0
        while x < len(r):
            c = r[x]
            if c == ".": x += 1; continue
            x2 = x
            while x2 + 1 < len(r) and r[x2 + 1] == c: x2 += 1
            out.append(f'<rect x="{x}" y="{y}" width="{x2-x+1}" height="1" fill="{pal[c]}"/>'); x = x2 + 1
    (ROOT / name).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {len(g[0])} {len(g)}" width="{len(g[0])*16}" height="{len(g)*16}" shape-rendering="crispEdges">\n' + "\n".join(out) + "\n</svg>\n")
def bbox_crop(im): return im.crop(im.getbbox())
GRAY = w.pal("#9A9A9A", "#5FD6E0")
TP = {**BASE, **GRAY}

# ---------- 1. Menubalk (definitief) ----------
for src, dst in (("tikk-slaap", "tikk-idle"), ("tikk-werk-a", "tikk-tracking-1"), ("tikk-werk-b", "tikk-tracking-2")):
    shutil.copy(w.OUT / f"{src}-mono.png", ROOT / "Menubalk" / f"{dst}.png")
    shutil.copy(w.OUT / f"{src}-mono@2x.png", ROOT / "Menubalk" / f"{dst}@2x.png")

# ---------- 2. Tikk-poses ----------
def both_arms(g):
    g = w.raise_left(g); g = w.raise_left([r[::-1] for r in g]); return [r[::-1] for r in g]
OPEN_LAMP = "...KBKBBWL"; OFF_LAMP = "...KBKBBWK"
master = w.build(w.LIT_TOP, w.EYES["tikk_open"], w.MOUTH_OPEN, OPEN_LAMP)
leeg = w.put(both_arms(w.build(("........KK", "........KK", ".........K"), w.EYES["tikk_open"], "...KBBBBBW", OFF_LAMP)),
             [(8, 8), (8, 9), (13, 8), (13, 9)], "K")                                           # kijkt opzij
leeg = w.put(leeg, [(16, 0), (17, 0), (18, 0), (18, 1), (17, 2), (17, 4)], "s")                 # vraagteken
klaar = w.build(w.LIT_TOP, w.EYES["tikk_open"], "...KBBBWWW", OPEN_LAMP)
klaar = w.put(w.put(klaar, [(x, 7) for x in (6, 7, 8)] + [(x, 9) for x in (6, 7, 8)], "K"), [(6, 8), (7, 8), (8, 8)], "e")  # knipoog
klaar = w.put(both_arms(klaar), [(17, 0), (16, 1), (17, 1), (18, 1), (17, 2)], "s")                                           # blij + glinster
oeps_eyes = ("...KBKEKEK", "..KKBKKEKK", "..KKBKEKEK")
oeps = w.build(("..........", "..........", ".........K"), oeps_eyes, "...KBBBWBW", OFF_LAMP)
oeps = w.put(w.put(oeps, [(10, 1), (11, 1), (12, 1), (12, 2)], "K"), [(1, 1), (1, 2), (0, 3), (1, 3), (2, 3), (0, 4), (1, 4), (2, 4), (0, 5), (1, 5), (2, 5)], "z")   # slap + zweetdruppel
POSES = {"tikk-hoofdfiguur": master, "tikk-lege-staat": leeg, "tikk-klaar": klaar, "tikk-oeps": oeps, "tikk-slaap": w.FIG["tikk-slaap"][0]}
for n, g in POSES.items():
    svg(g, TP, f"Tikk/{n}.svg"); render(g, TP, 24).save(ROOT / "Tikk" / f"{n}.png")
    w.mono_png(g, 1).save(ROOT / "Tikk" / f"{n}-mono.png"); w.mono_png(g, 2).save(ROOT / "Tikk" / f"{n}-mono@2x.png")
    (ROOT / "Tikk" / f"{n}-mono.svg").write_text(w.svg(g))

# ---------- 3. App-iconen ----------
FIGS = {"tikk": (master, TP, ORANGE), "moola": (w.FIG["moola"][0], {**BASE, **w.pal(*w.FIG["moola"][1:])}, GREEN),
        "brix": (w.FIG["brix"][0], {**BASE, **w.pal(*w.FIG["brix"][1:])}, BLUE)}
def squircle(size, r, ss=4):
    m = Image.new("L", (size * ss,) * 2, 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, size * ss - 1, size * ss - 1], r * ss, fill=255)
    return m.resize((size, size), Image.LANCZOS)
def make_icon(g, pal, bg):
    S = 1024; cv = Image.new("RGBA", (S, S), (0, 0, 0, 0)); body = 824; off = (S - body) // 2
    mask = squircle(body, 184)
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0)); sh.paste((0, 0, 0, 90), (off, off + 14), mask); cv.alpha_composite(sh.filter(ImageFilter.GaussianBlur(14)))
    tile = Image.new("RGBA", (body, body), bg)
    hi = Image.new("RGBA", (body, body), (255, 255, 255, 0)); gp = hi.load()
    for y in range(body):
        a = int(46 * max(0, 1 - y / (body * 0.7)))
        for x in range(body): gp[x, y] = (255, 255, 255, a)
    tile.alpha_composite(hi)
    fig = bbox_crop(render(g, pal, 1)); sc = 560 // max(fig.size); fig = fig.resize((fig.width * sc, fig.height * sc), Image.NEAREST)
    fs = Image.new("RGBA", tile.size, (0, 0, 0, 0)); fs.paste((0, 0, 0, 70), ((body - fig.width) // 2, (body - fig.height) // 2 + 22), fig.split()[3])
    tile.alpha_composite(fs.filter(ImageFilter.GaussianBlur(10)))
    tile.alpha_composite(fig, ((body - fig.width) // 2, (body - fig.height) // 2 + 8))
    tile.putalpha(mask); cv.alpha_composite(tile, (off, off)); return cv
SIZES = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
for n, (g, pal, bg) in FIGS.items():
    d = ROOT / "AppIcon" / n / "AppIcon.appiconset"; d.mkdir(parents=True, exist_ok=True)
    big = make_icon(g, pal, bg); big.save(ROOT / "AppIcon" / f"{n}-1024.png")
    imgs = []
    for s, sc in SIZES:
        fn = f"icon_{s}x{s}" + ("@2x" if sc == 2 else "") + ".png"; big.resize((s * sc, s * sc), Image.LANCZOS).save(d / fn)
        imgs.append({"size": f"{s}x{s}", "idiom": "mac", "filename": fn, "scale": f"{sc}x"})
    (d / "Contents.json").write_text(json.dumps({"images": imgs, "info": {"author": "xcode", "version": 1}}, indent=2))

# ---------- 4. Woordmerken (pixel-letters, 12 rijen) ----------
xh = lambda rows: ["." * len(rows[0])] * 4 + rows
LET = {
 "t": ["......", "..XX..", "..XX..", "..XX..", "XXXXXX", "XXXXXX", "..XX..", "..XX..", "..XX..", "..XX..", "..XXXX", "..XXXX"],
 "i": ["XX", "XX", "..", ".."] + ["XX"] * 8, "l": ["XX"] * 12,
 "k": ["XX...."] * 4 + ["XX..XX", "XX.XX.", "XXXX..", "XXXX..", "XX.XX.", "XX..XX", "XX..XX", "XX..XX"],
 "b": ["XX...."] * 4 + ["XXXXX.", "XXXXXX", "XX..XX", "XX..XX", "XX..XX", "XX..XX", "XXXXXX", "XXXXX."],
 "o": xh([".XXXX.", "XXXXXX", "XX..XX", "XX..XX", "XX..XX", "XX..XX", "XXXXXX", ".XXXX."]),
 "a": xh([".XXXX.", "XXXXXX", "....XX", ".XXXXX", "XXXXXX", "XX..XX", "XXXXXX", ".XXXXX"]),
 "r": xh(["XXXXX.", "XXXXXX", "XX..XX", "XX....", "XX....", "XX....", "XX....", "XX...."]),
 "m": xh([".XXXXXX.", "XXXXXXXX"] + ["XX.XX.XX"] * 6),
 "x": xh(["XX..XX", "XX..XX", ".XXXX.", "..XX..", "..XX..", ".XXXX.", "XX..XX", "XX..XX"]),
 ".": ["..."[:2]] * 10 + ["XX", "XX"]}
for k, v in LET.items(): assert len(v) == 12 and len({len(r) for r in v}) == 1, k
def wordmark(text):
    cols = []
    for i, ch in enumerate(text):
        L = LET[ch]; mark = "a" if ch == "." else "K"
        for x in range(len(L[0])): cols.append([mark if L[y][x] == "X" else "." for y in range(12)])
        if i < len(text) - 1: cols.append(["."] * 12)
    return ["".join(c[y] for c in cols) for y in range(12)]
ACC = {"tikk": ORANGE, "moola": "#6F9A79", "brix": "#5F86AD"}
VAR = {"licht": (INK, None), "donker": (CREAM, None), "zwart": ("#000000", "#000000"), "wit": ("#FFFFFF", "#FFFFFF")}
for n in ("tikk", "moola", "brix"):
    g = wordmark(n + ".")
    for v, (ink, acc) in VAR.items():
        pal = {"K": ink, "a": acc or ACC[n]}
        svg(g, pal, f"Woordmerk/{n}-{v}.svg")
        for sc in (1, 2, 3): render(g, pal, sc).save(ROOT / "Woordmerk" / f"{n}-{v}" f"{'' if sc == 1 else f'@{sc}x'}.png")
WM = {n: wordmark(n + ".") for n in ("tikk", "moola", "brix")}

# ---------- 5. Onboarding (40x26) ----------
def canvas_(wd, ht): return [["."] * wd for _ in range(ht)]
def rect(cv, x, y, wd, ht, ch):
    for yy in range(y, y + ht):
        for xx in range(x, x + wd): cv[yy][xx] = ch
def card(cv, x, y, wd, ht): rect(cv, x, y, wd, ht, "K"); rect(cv, x + 1, y + 1, wd - 2, ht - 2, "W")
def stamp(cv, x, y, rows, ch):
    for dy, r in enumerate(rows):
        for dx, c in enumerate(r):
            if c == "X": cv[y + dy][x + dx] = ch
def with_tikk(g):
    cv = canvas_(40, 26)
    for y, r in enumerate(g):
        for x, c in enumerate(r):
            if c != ".": cv[y + 6][x] = c
    return cv
HEART = [".XX...XX.", "XXXX.XXXX", "XXXXXXXXX", "XXXXXXXXX", ".XXXXXXX.", "..XXXXX..", "...XXX...", "....X...."]
SMALL = [".X.X.", "XXXXX", ".XXX.", "..X.."]
o1 = with_tikk(w.raise_left(master)); stamp(o1, 25, 4, HEART, "r"); stamp(o1, 35, 2, SMALL, "o"); stamp(o1, 22, 14, SMALL, "r")
o2 = with_tikk(w.raise_left(master)); card(o2, 22, 2, 17, 22); rect(o2, 23, 4, 15, 5, "q")
for i, (col, bar) in enumerate((("o", "o"), ("n", "l"), ("u", "l"))):
    y = 5 + i * 6 + (0 if i == 0 else 0); rect(o2, 25, y + 0, 3, 3, col); rect(o2, 30, y + 1, 6 if i else 5, 1, bar); rect(o2, 30, y + 1, 5, 2, bar) if False else None
stamp(o2, 34, 5, ["X.", "XX", "X."], "K")
o3 = with_tikk(w.raise_left(master)); card(o3, 22, 2, 17, 22)
for x, hh, col in ((25, 4, "o"), (28, 8, "n"), (31, 5, "u"), (34, 10, "y")): rect(o3, x, 16 - hh, 2, hh, col)
rect(o3, 24, 16, 14, 1, "K"); rect(o3, 24, 19, 14, 3, "K"); rect(o3, 25, 20, 12, 1, "g"); rect(o3, 25, 20, 7, 1, "o")
ONB = {"onboarding-1-welkom": o1, "onboarding-2-klant": o2, "onboarding-3-overzicht": o3}
for n, g in ONB.items():
    g = ["".join(r) for r in g]; svg(g, TP, f"Onboarding/{n}.svg"); render(g, TP, 12).save(ROOT / "Onboarding" / f"{n}.png")

# ---------- 6. Palet ----------
CLIENT = ["#FF8A4C", "#91B89A", "#7FA3C7", "#F2C14E", "#E88FA3", "#A38BC9", "#5FB5B0", "#E0675A", "#B58A6A", "#969696"]
(ROOT / "Palet" / "klantkleuren.json").write_text(json.dumps({"merk": {"tikkOrange": ORANGE, "warmOffWhite": CREAM, "softBlack": INK, "mutedGray": "#969696", "softGreen": GREEN}, "klanten": CLIENT}, indent=2))
sw = Image.new("RGB", (len(CLIENT) * 80 + 20, 100), CREAM); sd = ImageDraw.Draw(sw)
for i, c in enumerate(CLIENT): sd.ellipse([20 + i * 80, 20, 80 + i * 80, 80], fill=c)
sw.save(ROOT / "Palet" / "klantkleuren.png")

# ---------- 7. Delen ----------
try: FONT = lambda s: ImageFont.truetype("/System/Library/Fonts/SFNSRounded.ttf", s)
except Exception: FONT = lambda s: ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", s)
FONT(10)
def fit(g, pal, px): return (lambda im: im.resize((im.width * (px // max(im.size)), im.height * (px // max(im.size))), Image.NEAREST))(bbox_crop(render(g, pal, 1)))
icon = Image.open(ROOT / "AppIcon" / "tikk-1024.png")
icon.crop((100, 100, 924, 924)).resize((512, 512), Image.LANCZOS).save(ROOT / "Delen" / "avatar-512.png")
for s in (32, 180): icon.crop((100, 100, 924, 924)).resize((s, s), Image.LANCZOS).save(ROOT / "Delen" / f"favicon-{s}.png")
shutil.copy(ROOT / "Woordmerk" / "tikk-licht.svg", ROOT / "Delen" / "wordmark-licht.svg")
og = Image.new("RGBA", (1200, 630), CREAM); od = ImageDraw.Draw(og)
od.ellipse([60, 75, 540, 555], fill=ORANGE)
f = fit(master, TP, 400); og.alpha_composite(f, (100 + (400 - f.width) // 2, 110 + (400 - f.height) // 2))
wm = render(WM["tikk"], {"K": INK, "a": ORANGE}, 16); og.alpha_composite(wm, (620, 200)); od.text((620, 420), "Your tiny timekeeper.", fill=INK, font=FONT(46))
od.text((620, 490), "Urenregistratie in je menubalk.", fill="#969696", font=FONT(30)); og.convert("RGB").save(ROOT / "Delen" / "og-1200x630.png")
dmg = Image.new("RGBA", (1320, 800), CREAM); dd = ImageDraw.Draw(dmg)
dmg.alpha_composite(render(WM["tikk"], {"K": INK, "a": ORANGE}, 6), (660 - 78, 70))
arrow = ["....XX......", "....XXX.....", "XXXXXXXX....", "XXXXXXXXX...", "XXXXXXXXXX..", "XXXXXXXXX...", "XXXXXXXX....", "....XXX.....", "....XX......"]
ag = [r for r in arrow]; dmg.alpha_composite(render(ag, {"X": ORANGE}, 14).resize((168, 126), Image.NEAREST), (576, 330))
t = "Sleep tikk. naar Programma's"; tw = dd.textlength(t, font=FONT(40)); dd.text(((1320 - tw) / 2, 620), t, fill=INK, font=FONT(40))
dmg.convert("RGB").save(ROOT / "Delen" / "dmg-achtergrond-1320x800.png")

# ---------- Overzicht ----------
ov = Image.new("RGB", (1500, 1480), CREAM); od = ImageDraw.Draw(ov); lab = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 20)
def paste(im, x, y): ov.paste(im, (x, y), im if im.mode == "RGBA" else None)
od.text((20, 10), "App-iconen (1024 → 256)", fill=INK, font=lab)
for i, n in enumerate(("tikk", "moola", "brix")): paste(Image.open(ROOT / "AppIcon" / f"{n}-1024.png").resize((300, 300), Image.LANCZOS), 20 + i * 320, 40)
for i, s in enumerate((128, 64, 32, 16)): paste(Image.open(ROOT / "AppIcon" / "tikk-1024.png").resize((s, s), Image.LANCZOS), 1000 + sum((128, 64, 32, 16)[:i]) + i * 20, 200)
od.text((20, 360), "Woordmerken", fill=INK, font=lab)
for i, n in enumerate(("tikk", "moola", "brix")):
    for j, (v, bg) in enumerate((("licht", CREAM), ("donker", INK))):
        x = 20 + i * 480; y = 395 + j * 110; od.rectangle([x, y, x + 460, y + 100], fill=bg)
        paste(render(WM[n], {"K": INK if v == "licht" else CREAM, "a": ACC[n]}, 5), x + 20, y + 20)
od.text((20, 630), "Tikk-poses (kleur + menubalk-mono)", fill=INK, font=lab)
for i, n in enumerate(POSES):
    x = 20 + i * 290; paste(render(POSES[n], TP, 12), x, 665)
    od.rectangle([x, 920, x + 270, 1000], fill=(236, 236, 236)); paste(w.mono_png(POSES[n], 1), x + 10, 940); paste(w.mono_png(POSES[n], 2), x + 50, 930); paste(w.mono_png(POSES[n], 3), x + 110, 925)
    od.text((x, 1005), n, fill=INK, font=lab)
od.text((20, 1040), "Onboarding", fill=INK, font=lab)
for i, n in enumerate(ONB): paste(Image.open(ROOT / "Onboarding" / f"{n}.png").resize((470, 305), Image.NEAREST), 20 + i * 490, 1070)
paste(sw.resize((sw.width // 1, sw.height)), 20, 1390)
ov.save(ROOT / "overzicht.png"); print("ok")
