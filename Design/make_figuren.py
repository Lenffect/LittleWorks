"""Nieuwe pixel-art figuren (los van de briefing). Run: python3 make_figuren.py"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).parent / "Tikk" / "figuren"; OUT.mkdir(parents=True, exist_ok=True)
P = dict(K="#242424", Q="#4A4A4A", S="#F2C29B", W="#F8F7F4", G="#9A9A9A", B="#4F7FC1", b="#36588C",
         Y="#F5C842", R="#D8514A", O="#FF8A4C", H="#8A5A3B", P="#F4A6B8", C="#5FD6E0")

F = {}
F["1 tovenaar"] = [
".......KK.......","......KBBK......",".....KBBBBK.....",".....KBYBBK.....","....KBBBBBBK....",
"..KKKKKKKKKKKK..","....KSSSSSSK....","....KSKSSKSK....","...KWSSSSSSWK...","...KWWWWWWWWK...",
"..KBBWWWWWWBBK..","..KBBBBBBBBBBK..","..KBBBBYYBBBBK..","..KBBBBBBBBBBK..","...KbbbbbbbbK...","...KKKKKKKKKK..."]
F["2 robot"] = [
"......KRRK......",".......KK.......","..KKKKKKKKKKKK..","..KGGGGGGGGGGK..","..KGKKKKKKKKGK..",
"..KGKCCKKCCKGK..","..KGKKKKKKKKGK..","..KGGGGGGGGGGK..","..KKKKKKKKKKKK..","...KGGGGGGGGK...",
".KKKGGWWWWGGKKK.",".KGKGGWRRWGGKGK.",".KKKGGWWWWGGKKK.","...KGGGGGGGGK...","...KGGKKKKGGK...","..KKKKK..KKKKK.."]
F["3 katje"] = [
"..KK........KK..","..KOK......KOK..","..KOOKKKKKKOOK..",".KOOOOOOOOOOOOK.",".KOOKKOOOOKKOOK.",
".KOOKKOOOOKKOOK.",".KOPOOOKKOOOPOK.",".KOOOOOWWOOOOOK.","..KKOOOOOOOOKK..","..KOOOOOOOOOOK..",
"..KOOOWWWWOOOK..","..KOOOWWWWOOOK..","..KOOOOOOOOOOK..","..KOOOOOOOOOOK..","..KKOOOKKOOOKK..","...KKKK..KKKK..."]
F["4 astronaut"] = [
"....KKKKKKKK....","...KWWWWWWWWK...","..KWKKKKKKKKWK..","..KWKBBBBBBKWK..","..KWKBCBBCBKWK..",
"..KWKBBBBBBKWK..","..KWKKKKKKKKWK..","...KWWWWWWWWK...","....KKKKKKKK....","...KWWWWWWWWK...",
"..KKWWWWWWWWKK..",".KWKWWOOOOWWKWK.",".KWKWWWWWWWWKWK.",".KKKWWWWWWWWKKK.","...KWWK..KWWK...","..KKKKK..KKKKK.."]
F["5 ninja"] = [
"....KKKKKKKK....","...KQQQQQQQQK...","...KQQQQQQQQK...","...KRRRRRRRRK...","...KSSSSSSSSK...",
"...KSKKSSKKSK...","...KQQQQQQQQK...","..KKOOOOOOOOKK..","..KQQQQQQQQQQK..",".KKQQQQQQQQQQKK.",
".KSKQQQQQQQQKSK.",".KKKQQQOOQQQKKK.","...KQQQQQQQQK...","...KQQKKKKQQK...","...KQQK..KQQK...","..KKKKK..KKKKK.."]
F["6 ridder"] = [
".......RR.......","......KRRK......","....KKKKKKKK....","...KGGGGGGGGK...","...KGGGGGGGGK...",
"...KGSSSSSSGK...","...KGSKSSKSGK...","...KGSSSSSSGK...","....KGGGGGGK....","..KKGGGGGGGGKK..",
".KGGKGGGGGGKGGK.",".KGGKGGRRGGKGGK.",".KGGKGGGGGGKGGK.","..KKKGGGGGGKKK..","...KGGK..KGGK...","..KKKKK..KKKKK.."]
F["7 spookje"] = [
"....KKKKKKKK....","...KWWWWWWWWK...","..KWWWWWWWWWWK..","..KWWWWWWWWWWK..","..KWWKKWWKKWWK..",
"..KWWKKWWKKWWK..","..KWPWWWWWWPWK..","..KWWWWKKWWWWK..","..KWWWWWWWWWWK..","..KGWWWWWWWWGK..",
"..KGWWWWWWWWGK..","..KGGWWWWWWGGK..","..KWWWWWWWWWWK..","..KWWWWWWWWWWK..","..KWWKWWWWKWWK..","..KKK.KKKK.KKK.."]
F["8 freelancer"] = [
"....KKKKKKKK....","...KHHHHHHHHK...","..KHHHHHHHHHHK..",".KGKHSSSSSSHKGK.",".KGKSSKSSKSSKGK.",
".KGKSPSSSSPSKGK.","..KKSSSKKSSSKK..","...KKSSSSSSKK...","...KOOOOOOOOK...","..KOOOOOOOOOOK..",
".KOOKOOWWOOKOOK.",".KSKOOOOOOOOKSK.",".KKKOOOOOOOOKKK.","...KBBBBBBBBK...","...KBBK..KBBK...","..KKKKK..KKKKK.."]
for n, g in F.items():
    assert len(g) == 16 and all(len(r) == 16 for r in g), (n, [len(r) for r in g])

def png(g, scale, mono=False, color=None):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(g):
        for x, c in enumerate(row):
            if c != ".": im.putpixel((x, y), color if mono else Image.new("RGB", (1, 1), P[c]).getpixel((0, 0)) + (255,))
    return im.resize((16 * scale, 16 * scale), Image.NEAREST)

def svg(g, mono=False):
    rects = []
    for y, row in enumerate(g):
        x = 0
        while x < 16:
            c = row[x]
            if c == ".": x += 1; continue
            x2 = x
            while x2 + 1 < 16 and row[x2 + 1] == c: x2 += 1
            rects.append(f'<rect x="{x}" y="{y}" width="{x2-x+1}" height="1" fill="{"#000" if mono else P[c]}"/>')
            x = x2 + 1
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" width="512" height="512" shape-rendering="crispEdges">\n' + "\n".join(rects) + "\n</svg>\n"

for n, g in F.items():
    slug = n.split()[0] + "-" + n.split()[1]
    (OUT / f"{slug}.svg").write_text(svg(g))

S = 12
font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 22)
tiny = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 15)
CW = 16 * S + 70; W = 4 * CW + 40
sheet = Image.new("RGB", (W, 2 * 260 + 150 + 2 * 120 + 60), "#F8F7F4"); d = ImageDraw.Draw(sheet)
for i, (n, g) in enumerate(F.items()):
    x, y = 20 + (i % 4) * CW + 35, 20 + (i // 4) * 260
    sheet.paste(png(g, S), (x, y), png(g, S)); d.text((x, y + 16 * S + 8), n, fill="#242424", font=font)
# cast-lineup op echte grootte (2x) licht/donker + silhouet-test 1x/2x/4x
y0 = 2 * 260 + 30
for j, (bg, ink) in enumerate([("#F8F7F4", (0, 0, 0, 255)), ("#242424", (255, 255, 255, 255))]):
    yy = y0 + j * 130; d.rectangle([20, yy, W - 20, yy + 115], fill=bg)
    for i, (n, g) in enumerate(F.items()):
        x = 36 + i * 128
        m = png(g, 1, True, ink)
        sheet.paste(m, (x, yy + 14), m)
        m2 = png(g, 2, True, ink); sheet.paste(m2, (x + 24, yy + 14), m2)
        m4 = png(g, 3, True, ink); sheet.paste(m4, (x + 60, yy + 14), m4)
y1 = y0 + 2 * 130 + 10
d.rectangle([20, y1, W - 20, y1 + 100], fill="#F8F7F4")
for i, (n, g) in enumerate(F.items()):
    im = png(g, 4); sheet.paste(im, (36 + i * 128 - 0, y1 + 18), im) if False else None
sheet = sheet.crop((0, 0, W, y0 + 2 * 130 + 10)); sheet.save(OUT / "figuren.png"); print("ok")
