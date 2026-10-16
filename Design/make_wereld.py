"""Little Works-wereldje: Tikk (slaap/werk), Moola, Brix. 16x16 figuur op 18x18 menubalk-canvas. Run: python3 make_wereld.py"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).parent / "Tikk" / "wereld"; OUT.mkdir(parents=True, exist_ok=True)
P = dict(K="#242424", G="#9A9A9A", g="#6B6B6B", O="#FF8A4C", W="#F8F7F4", C="#5FD6E0", c="#3A8A91", B="#4F7FC1",
         S="#F2C29B", Y="#F5C842", P="#F4A6B8", p="#D9778F")

def tikk(bulb, top, bot, lamp):   # top/bot: ogenrijen (open: 2 px hoog, slapend: 1 dunne lijn)
    return [
f"......K{bulb}{bulb}K......", ".......KK.......", "..KKKKKKKKKKKK..", "..KGGGGGGGGGGK..", "..KGKKKKKKKKGK..",
f"..KGK{top}{top}KK{top}{top}KGK..", f"..KGK{bot}{bot}KK{bot}{bot}KGK..", "..KGKKKKKKKKGK..", "..KKKKKKKKKKKK..", "...KGGGGGGGGK...",
".KKKGGWWWWGGKKK.", f".KGKGGW{lamp}{lamp}WGGKGK.", ".KKKGGWWWWGGKKK.", "...KGGGGGGGGK...", "...KGGKKKKGGK...", "..KKKKK..KKKKK.."]
Z = [(14, 0), (15, 0), (16, 0), (17, 0), (16, 1), (15, 2), (14, 3), (15, 3), (16, 3), (17, 3)]   # z op 18x18 canvas

F = {
 "tikk-slaap":  (tikk("g", "K", "c", "g"), Z),
 "tikk-werk-a": (tikk("O", "C", "C", "O"), []),
 "tikk-werk-b": (tikk("g", "C", "C", "O"), []),
 "moola": ([
"..KK........KK..", "..KpK......KpK..", "..KppKKKKKKppK..", ".KppppppppppppK.", ".KpppWpppWpppK..".replace(".KpppWpppWpppK..", ".KpppWppppWpppK."),
".KpppKppppKpppK.", ".KpppPPPPPPpppK.", ".KpppPKPPKPpppK.", ".KpppPPPPPPpppK.", "..KKpppppppppKK.".replace("..KKpppppppppKK.", "..KKppppppppKK.."),
"..KppppppppppK..", "..KpppYYYYpppK..", "..KpppYYYYpppK..", "..KppppppppppK..", "...KppK..KppK...", "..KKKKK..KKKKK.."], []),
 "brix": ([
"......KKKK......", "....KKYYYYKK....", "...KYYYYYYYYK...", "...KYYYKKYYYK...", "..KKKKKKKKKKKK..",
"...KSSSSSSSSK...", "...KSSKSSKSSK...", "...KSPSSSSPSK...", "....KSSKKSSK....", "...KWWWWWWWWK...",
"..KKBWWWWWWBKK..", ".KSKBBBBBBBBKSK.", ".KKKBBBYYBBBKKK.", "...KBBBBBBBBK...", "...KBBK..KBBK...", "..KKKKK..KKKKK.."], []),
}
for n, (g, _) in F.items():
    assert len(g) == 16 and all(len(r) == 16 for r in g), (n, [(i, len(r)) for i, r in enumerate(g) if len(r) != 16])

def lum(h): r, g, b = (int(h[i:i+2], 16) for i in (1, 3, 5)); return (0.299*r + 0.587*g + 0.114*b) / 255
def canvas(fig, extra):                       # 18x18: figuur op (1,2), effecten erbij
    cv = [["."] * 18 for _ in range(18)]
    for y, r in enumerate(fig):
        for x, c in enumerate(r): cv[y + 2][x + 1] = c
    for x, y in extra: cv[y][x] = "B"
    return cv
def is_black(c): return c != "." and (c == "K" or lum(P[c]) < 0.62)

def png(cv, scale, mono=False, ink=(0, 0, 0, 255)):
    im = Image.new("RGBA", (18, 18), (0, 0, 0, 0))
    for y, r in enumerate(cv):
        for x, c in enumerate(r):
            if mono and is_black(c): im.putpixel((x, y), ink)
            elif not mono and c != ".": im.putpixel((x, y), tuple(int(P[c][i:i+2], 16) for i in (1, 3, 5)) + (255,))
    return im.resize((18 * scale, 18 * scale), Image.NEAREST)
def svg(cv, mono=False):
    rects = []
    for y, r in enumerate(cv):
        x = 0
        while x < 18:
            c = r[x]
            ok = is_black(c) if mono else c != "."
            if not ok: x += 1; continue
            x2 = x
            while x2 + 1 < 18 and r[x2 + 1] == c if not mono else (x2 + 1 < 18 and is_black(r[x2 + 1])): x2 += 1
            rects.append(f'<rect x="{x}" y="{y}" width="{x2-x+1}" height="1"' + ('' if mono else f' fill="{P[c]}"') + '/>')
            x = x2 + 1
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 18 18" width="512" height="512" shape-rendering="crispEdges"'
            + (' fill="#000"' if mono else '') + '>\n' + "\n".join(rects) + "\n</svg>\n")

CV = {n: canvas(g, ex) for n, (g, ex) in F.items()}
for n, cv in CV.items():
    (OUT / f"{n}.svg").write_text(svg(cv)); (OUT / f"{n}-mono.svg").write_text(svg(cv, True))
    png(cv, 1, True).save(OUT / f"{n}-mono.png"); png(cv, 2, True).save(OUT / f"{n}-mono@2x.png")
    png(cv, 16).save(OUT / f"{n}.png")
# animatie: werken (bulb knippert)
fr = [png(CV[k], 16).convert("RGBA") for k in ("tikk-werk-a", "tikk-werk-b")]
bg = lambda im: (lambda b: (b.alpha_composite(im), b.convert("P"))[1])(Image.new("RGBA", im.size, "#F8F7F4"))
bg(fr[0]).save(OUT / "tikk-werk.gif", save_all=True, append_images=[bg(fr[1])], duration=500, loop=0)

# Preview
font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 18); tiny = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 14)
S, cw = 9, 18 * 9 + 24; names = list(CV); W = len(names) * cw + 20
sheet = Image.new("RGB", (W, 18 * S + 40 + 2 * 170), "#F8F7F4"); d = ImageDraw.Draw(sheet)
for i, n in enumerate(names):
    x = 14 + i * cw; im = png(CV[n], S); sheet.paste(im, (x, 10), im); d.text((x, 18 * S + 16), n, fill="#242424", font=font)
for j, (bg_, ink) in enumerate([("#F8F7F4", (0, 0, 0, 255)), ("#242424", (255, 255, 255, 255))]):
    y = 18 * S + 46 + j * 170; d.rectangle([8, y, W - 8, y + 160], fill=bg_)
    for i, n in enumerate(names):
        x = 14 + i * cw
        a = png(CV[n], 1, True, ink); sheet.paste(a, (x, y + 12), a)
        b = png(CV[n], 2, True, ink); sheet.paste(b, (x + 30, y + 12), b)
        c = png(CV[n], 6, True, ink); sheet.paste(c, (x + 10, y + 52), c)
sheet.save(OUT / "wereld.png"); print("ok")
