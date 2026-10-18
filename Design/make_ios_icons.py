"""iOS-app-iconen: volledig vierkant (iOS maskeert zelf), zonder schaduwrand. Run: python3 make_ios_icons.py
Schrijft previews naar Assets/AppIconiOS en de catalogus naar Apps/Tikk/ResourcesiOS/Icons.xcassets."""
import json, shutil
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import make_wereld20 as w

HERE = Path(__file__).parent
PREV = HERE / "Assets" / "AppIconiOS"
CAT = HERE.parent / "Apps" / "Tikk" / "ResourcesiOS" / "Icons.xcassets"
INK, CREAM, ORANGE, GREEN, BLUE = "#242424", "#F8F7F4", "#FF8A4C", "#91B89A", "#7FA3C7"
hx = lambda h: tuple(int(h[i:i+2], 16) for i in (1, 3, 5))
BASE = {**w.BASE, "g": "#D9D9D9", "o": ORANGE, "n": GREEN, "u": BLUE, "y": "#F2C14E", "q": "#FFE3D2", "r": "#E88FA3", "x": "#9A9A9A", "l": "#D9D9D9"}
PAL = {**BASE, **w.pal("#9A9A9A", "#5FD6E0")}
GRID = w.build(w.LIT_TOP, w.EYES["tikk_open"], w.MOUTH_OPEN, "...KBKBBWL")
S = 1024

def figure(pal, target):
    h, wd = len(GRID), len(GRID[0]); im = Image.new("RGBA", (wd, h), (0, 0, 0, 0))
    for y, r in enumerate(GRID):
        for x, c in enumerate(r):
            if c != ".": im.putpixel((x, y), hx(pal[c]) + (255,))
    im = im.crop(im.getbbox()); sc = max(1, target // max(im.size))
    return im.resize((im.width * sc, im.height * sc), Image.NEAREST)

def gradient(top, bottom, size=S):
    g = Image.new("RGBA", (size, size)); px = g.load(); a, b = hx(top), hx(bottom)
    for y in range(size):
        t = y / (size - 1); c = tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)
        for x in range(size): px[x, y] = c
    return g

def shadowed(bg, fig, dy=22, blur=12, alpha=70, cy=0):
    cv = bg.copy(); pos = ((S - fig.width) // 2, (S - fig.height) // 2 + cy)
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0)); sh.paste((0, 0, 0, alpha), (pos[0], pos[1] + dy), fig.split()[3])
    cv.alpha_composite(sh.filter(ImageFilter.GaussianBlur(blur))); cv.alpha_composite(fig, pos); return cv

def shine(bg):
    hi = Image.new("RGBA", (S, S), (255, 255, 255, 0)); p = hi.load()
    for y in range(S):
        a = int(46 * max(0, 1 - y / (S * 0.7)))
        for x in range(S): p[x, y] = (255, 255, 255, a)
    out = bg.copy(); out.alpha_composite(hi); return out

def mono(dark_is_black=True):
    """Alleen zwart en wit: donkere tinten zwart, lichte tinten wit (of omgekeerd)."""
    pal = {}
    for k, v in PAL.items():
        lum = 0.299 * hx(v)[0] + 0.587 * hx(v)[1] + 0.114 * hx(v)[2]
        light = lum > 110
        pal[k] = "#FFFFFF" if light == dark_is_black else "#000000"
    return pal

DARKPAL = {**PAL, "K": "#E9E6DF"}   # lichte omlijning, anders verdwijnt Tikk in het donker

def tinted(bg_black):
    pal = {}
    for k, v in PAL.items():
        r, g, b = hx(v); l = round(0.299 * r + 0.587 * g + 0.114 * b); pal[k] = "#%02X%02X%02X" % (l, l, l)
    return pal

def glass():
    bg = gradient("#FFB37A", "#6D6CF5")
    blobs = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(blobs)
    for (x, y, r, c) in ((200, 220, 330, (255, 120, 170, 200)), (820, 300, 300, (90, 214, 224, 190)),
                         (700, 880, 360, (140, 110, 255, 210)), (140, 820, 260, (255, 200, 110, 190))):
        d.ellipse([x - r, y - r, x + r, y + r], fill=c)
    bg.alpha_composite(blobs.filter(ImageFilter.GaussianBlur(120)))
    plate, rad = 700, 176; off = (S - plate) // 2
    m = Image.new("L", (plate * 4,) * 2, 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, plate * 4 - 1, plate * 4 - 1], rad * 4, fill=255)
    m = m.resize((plate, plate), Image.LANCZOS)
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0)); sh.paste((20, 10, 60, 110), (off, off + 34), m)
    bg.alpha_composite(sh.filter(ImageFilter.GaussianBlur(34)))
    blur = bg.crop((off, off, off + plate, off + plate)).filter(ImageFilter.GaussianBlur(10))   # matglas
    tile = Image.alpha_composite(blur, Image.new("RGBA", (plate, plate), (255, 255, 255, 64)))
    gl = Image.new("RGBA", (plate, plate), (255, 255, 255, 0)); p = gl.load()
    for y in range(plate):
        a = int(120 * max(0, 1 - y / (plate * 0.55)) ** 1.6)
        for x in range(plate): p[x, y] = (255, 255, 255, a)
    tile.alpha_composite(gl)
    ring = Image.new("RGBA", (plate, plate), (0, 0, 0, 0)); rp = ring.load()
    edge = ImageChops.subtract(m, m.filter(ImageFilter.MinFilter(9)))            # ~4px rand
    for y in range(plate):
        for x in range(plate):
            a = edge.getpixel((x, y))
            if a: rp[x, y] = (255, 255, 255, int(a * (0.95 - 0.7 * (x + y) / (2 * plate))))
    tile.alpha_composite(ring); tile.putalpha(ImageChops.multiply(tile.split()[3], m)); bg.alpha_composite(tile, (off, off))
    fig = figure(PAL, 520); out = shadowed(bg, fig, dy=26, blur=16, alpha=90, cy=4)
    gloss = Image.new("RGBA", (S, S), (0, 0, 0, 0)); gp = gloss.load(); pos = ((S - fig.width) // 2, (S - fig.height) // 2 + 4)
    fa = fig.split()[3]
    for y in range(fig.height):
        a = int(90 * max(0, 1 - y / (fig.height * 0.5)))
        for x in range(fig.width):
            if fa.getpixel((x, y)): gp[pos[0] + x, pos[1] + y] = (255, 255, 255, a)
    out.alpha_composite(gloss); return out

def plain(top, bottom, pal=PAL, target=620, shine_on=True, cy=8, shadow=70):
    bg = gradient(top, bottom)
    if shine_on: bg = shine(bg)
    return shadowed(bg, figure(pal, target), cy=cy, alpha=shadow)

ICONS = {   # naam: (afbeelding, titel NL)
    "TikkOranje": plain("#FFA06B", "#FF8A4C"),
    "TikkLicht": plain("#FFFFFF", "#EFEDE7", shine_on=False, shadow=40),
    "TikkDonker": plain("#2E2E32", "#161618", pal=DARKPAL, shine_on=False, shadow=0),
    "TikkZwartWit": plain("#FFFFFF", "#FFFFFF", pal=mono(True), shine_on=False, shadow=0),
    "TikkNacht": plain("#000000", "#000000", pal=mono(False), shine_on=False, shadow=0),
    "TikkGlas": glass(),
    "TikkMint": plain("#A9CDB1", "#91B89A"),
    "TikkHemel": plain("#9BBBD8", "#7FA3C7"),
}
DARK = plain("#2E2E32", "#161618", pal=DARKPAL, shine_on=False, shadow=0)
TINT = plain("#000000", "#000000", pal=tinted(True), shine_on=False, shadow=0)

PREV.mkdir(parents=True, exist_ok=True)
if CAT.exists(): shutil.rmtree(CAT)
CAT.mkdir(parents=True)
(CAT / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2))
info = {"author": "xcode", "version": 1}
for name, im in ICONS.items():
    im = im.convert("RGB"); im.save(PREV / f"{name}-1024.png")
    d = CAT / f"{name}.appiconset"; d.mkdir()
    imgs = [{"filename": "icon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}]
    im.save(d / "icon.png")
    if name == "TikkOranje":
        DARK.convert("RGB").save(d / "dark.png"); TINT.convert("RGB").save(d / "tinted.png")
        imgs += [{"appearances": [{"appearance": "luminosity", "value": "dark"}], "filename": "dark.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
                 {"appearances": [{"appearance": "luminosity", "value": "tinted"}], "filename": "tinted.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}]
    (d / "Contents.json").write_text(json.dumps({"images": imgs, "info": info}, indent=2))
    pv = CAT / f"IconPreview{name[4:]}.imageset"; pv.mkdir()      # voorbeeld voor de keuzelijst (afgeronde hoeken doet de app)
    im.resize((360, 360), Image.LANCZOS).save(pv / "preview.png")
    (pv / "Contents.json").write_text(json.dumps({"images": [{"filename": "preview.png", "idiom": "universal"}], "info": info}, indent=2))

sheet = Image.new("RGB", (4 * 330 + 30, 2 * 330 + 30), "#888")
for i, (n, im) in enumerate(ICONS.items()):
    t = im.convert("RGB").resize((300, 300), Image.LANCZOS); mk = Image.new("L", (300, 300), 0)
    ImageDraw.Draw(mk).rounded_rectangle([0, 0, 299, 299], 68, fill=255)
    sheet.paste(t, (30 + (i % 4) * 330, 30 + (i // 4) * 330), mk)
sheet.save(PREV / "overzicht.png"); print("klaar:", ", ".join(ICONS))
