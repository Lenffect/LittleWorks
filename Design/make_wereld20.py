"""Little Works-wereldje v3: 20x20, twee tinten (zwart + 50%), chibi-robots. Run: python3 make_wereld20.py"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).parent / "Tikk" / "wereld20"; OUT.mkdir(parents=True, exist_ok=True)
N = 20
SOLID, MID = set("Kzs"), set("B")          # alles anders = gat (transparant) in de menubalk
BASE = dict(K="#242424", W="#F8F7F4", L="#FF8A4C", Y="#F5C842", e="#3A8A91", z="#4F7FC1", s="#FF8A4C")

H = dict(h3="......KKKK", h4="....KKBBBB", h5="...KBBBBBB", h6="...KBKKKKK", h10="...KBKKKKK", h12="....KKBBBB", h13="......KKKK")
BODY = dict(r14=".....KBBBB", r15="...KKKBBWW", r17="...KKKBBWW", r18=".....KBBKK", r19="....KKKK..")
EYES = dict(
 tikk_open  =("...KBKEEEK", "..KKBKEEEK", "..KKBKEEEK"),
 tikk_closed=("...KBKKKKK", "..KKBKKKKK", "..KKBKeeeK"),
 moola      =("...KBKKEKK", "..KKBKEEEK", "..KKBKKEKK"),
 brix       =("...KBKKKKK", "..KKBKEEEE", "..KKBKEEEE"))

def build(top, eyes, mouth, r16):
    rows = [*top, *(H[k] for k in ("h3", "h4", "h5", "h6")), *eyes, H["h10"], mouth, H["h12"], H["h13"],
            BODY["r14"], BODY["r15"], r16, BODY["r17"], BODY["r18"], BODY["r19"]]
    assert len(rows) == N and all(len(r) == 10 for r in rows), [len(r) for r in rows]
    return [r + r[::-1] for r in rows]                           # spiegel: links -> rechts

def put(g, pts, ch):
    g = [list(r) for r in g]
    for x, y in pts: g[y][x] = ch
    return ["".join(r) for r in g]

def raise_left(g):    # linkerarm omhoog; kolommen 0-5 worden vervangen
    rep = {9: "KKK", 10: "KBK", 11: "KBK", 12: "KBK", 13: "KBK", 14: "KBK..K", 15: "KBKKKK", 16: "KKK..K", 17: ".....K"}
    g = list(g)
    for y, s in rep.items(): g[y] = s + g[y][len(s):]
    return g

MOUTH_OPEN, MOUTH_SLEEP = "...KBBBBWW", "...KBBBBBW"
LIT_TOP  = ("........KK", "........KL", ".........K")
Z_PTS = [(16, 0), (17, 0), (18, 0), (19, 0), (18, 1), (17, 2), (16, 3), (17, 3), (18, 3), (19, 3)]
SPARKS = [(6, 1), (13, 1), (5, 0), (14, 0)]

def tikk_sleep():
    g = build(("..........", "..........", ".........K"), EYES["tikk_closed"], MOUTH_SLEEP, "...KBKBBWK")
    g = put(g, [(10, 1), (11, 1), (12, 1), (12, 2)], "K")        # antenne hangt slap
    return put(g, Z_PTS, "z")
def tikk_werk():
    return put(raise_left(build(LIT_TOP, EYES["tikk_open"], MOUTH_OPEN, "...KBKBBWL")), SPARKS, "s")

FIG = {   # naam: (grid, lichaamskleur, oogkleur)
 "tikk-slaap":  (tikk_sleep(), "#9A9A9A", "#5FD6E0"),
 "tikk-werk-a": (tikk_werk(),  "#9A9A9A", "#5FD6E0"),
 "moola": (build((".......KKK", ".......KYY", "......KKKK"), EYES["moola"], "...KBBBWWW", "...KBKBWWW"), "#7AA886", "#F5C842"),
 "brix":  (build((".....KKKK.", ".....KEEK.", ".....KKKK."), EYES["brix"], "...KBBBWWW", "...KBKBBWK"), "#4F7FC1", "#FF8A4C"),
}
FIG["tikk-werk-b"] = ([r[::-1] for r in FIG["tikk-werk-a"][0]], "#9A9A9A", "#5FD6E0")
ORDER = ["tikk-slaap", "tikk-werk-a", "tikk-werk-b", "moola", "brix"]

def pal(body, eye): return {**BASE, "B": body, "E": eye}
def rgb(h): return tuple(int(h[i:i+2], 16) for i in (1, 3, 5))
def color_png(g, p, sc):
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    for y, r in enumerate(g):
        for x, c in enumerate(r):
            if c != ".": im.putpixel((x, y), rgb(p[c]) + (255,))
    return im.resize((N * sc, N * sc), Image.NEAREST)
def mono_png(g, sc, ink=(0, 0, 0)):
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    for y, r in enumerate(g):
        for x, c in enumerate(r):
            if c in SOLID: im.putpixel((x, y), ink + (255,))
            elif c in MID: im.putpixel((x, y), ink + (128,))
    return im.resize((N * sc, N * sc), Image.NEAREST)
def svg(g, p=None):
    out = []
    for y, r in enumerate(g):
        x = 0
        while x < N:
            c = r[x]; vis = c != "." if p else (c in SOLID or c in MID)
            if not vis: x += 1; continue
            x2 = x
            while x2 + 1 < N and r[x2 + 1] == c: x2 += 1
            fill = f' fill="{p[c]}"' if p else (' fill-opacity=".5"' if c in MID else "")
            out.append(f'<rect x="{x}" y="{y}" width="{x2-x+1}" height="1"{fill}/>'); x = x2 + 1
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {N} {N}" width="512" height="512" shape-rendering="crispEdges"'
            + ('' if p else ' fill="#000"') + '>\n' + "\n".join(out) + "\n</svg>\n")

for n in ORDER:
    g, body, eye = FIG[n]; p = pal(body, eye)
    (OUT / f"{n}.svg").write_text(svg(g, p)); (OUT / f"{n}-mono.svg").write_text(svg(g))
    color_png(g, p, 16).save(OUT / f"{n}.png")
    mono_png(g, 1).save(OUT / f"{n}-mono.png"); mono_png(g, 2).save(OUT / f"{n}-mono@2x.png")
fr = [Image.alpha_composite(Image.new("RGBA", (N * 16,) * 2, "#F8F7F4"), color_png(FIG[k][0], pal(*FIG[k][1:]), 16)).convert("P") for k in ("tikk-werk-a", "tikk-werk-b")]
fr[0].save(OUT / "tikk-werk.gif", save_all=True, append_images=fr[1:], duration=500, loop=0)

# Preview: kleur + menubalk-simulatie (licht/donker) op echte grootte (@1x, @2x) en uitvergroot
font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 17)
S, cw = 10, N * 10 + 30; W = len(ORDER) * cw + 20
sheet = Image.new("RGB", (W, N * S + 50 + 2 * 205), "#F8F7F4"); d = ImageDraw.Draw(sheet)
for i, n in enumerate(ORDER):
    x = 18 + i * cw; im = color_png(FIG[n][0], pal(*FIG[n][1:]), S); sheet.paste(im, (x, 8), im); d.text((x, N * S + 12), n, fill="#242424", font=font)
for j, (bg, ink) in enumerate([((236, 236, 236), (0, 0, 0)), ((38, 38, 38), (255, 255, 255))]):
    y = N * S + 40 + j * 205; d.rectangle([8, y, W - 8, y + 195], fill=bg)
    for i, n in enumerate(ORDER):
        x = 18 + i * cw; g = FIG[n][0]
        for im, ox, oy in ((mono_png(g, 1, ink), 0, 14), (mono_png(g, 2, ink), 34, 14), (mono_png(g, 6, ink), 0, 62)):
            sheet.paste(im, (x + ox, y + oy), im)
sheet.save(OUT / "wereld20.png"); print("ok")
