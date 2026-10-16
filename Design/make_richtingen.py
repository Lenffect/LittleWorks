"""Nieuwe, niet-pixel richtingen voor Tikk (vector). Run: python3 make_richtingen.py"""
import re, subprocess, tempfile
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).parent / "Tikk" / "richtingen"; OUT.mkdir(parents=True, exist_ok=True)
C = dict(BODY="#FF8A4C", LIGHT="#FFB48A", DARK="#E06A2C", CHEEK="#F26B45", WHITE="#F8F7F4", INK="#242424")

# elke regel: <element .../>; 'data-d' = alleen detail (valt weg in mono); INK = gaat uit het silhouet
R = {}
R["1 stopwatch"] = '''
<rect x="43" y="7" width="14" height="9" rx="4" fill="DARK"/>
<rect x="47" y="14" width="6" height="9" fill="DARK"/>
<circle cx="50" cy="57" r="36" fill="BODY"/>
<circle cx="50" cy="57" r="27.5" fill="WHITE" data-d="1"/>
<line x1="50" y1="34" x2="50" y2="39" stroke="INK" stroke-width="3" stroke-linecap="round" data-d="1"/>
<ellipse cx="40" cy="55" rx="3.8" ry="5.2" fill="INK"/>
<ellipse cx="60" cy="55" rx="3.8" ry="5.2" fill="INK"/>
<path d="M43.5 67 Q50 73 56.5 67" stroke="INK" stroke-width="3.2" fill="none" stroke-linecap="round"/>
<ellipse cx="32" cy="66" rx="4.5" ry="2.8" fill="CHEEK" opacity=".55" data-d="1"/>
<ellipse cx="68" cy="66" rx="4.5" ry="2.8" fill="CHEEK" opacity=".55" data-d="1"/>
<ellipse cx="35" cy="94" rx="9.5" ry="4.5" fill="DARK"/>
<ellipse cx="65" cy="94" rx="9.5" ry="4.5" fill="DARK"/>'''
R["2 de punt"] = '''
<circle cx="50" cy="50" r="41" fill="BODY"/>
<ellipse cx="33" cy="27" rx="11" ry="6" transform="rotate(-35 33 27)" fill="LIGHT" data-d="1"/>
<ellipse cx="36" cy="92" rx="9" ry="5" fill="DARK"/>
<ellipse cx="64" cy="92" rx="9" ry="5" fill="DARK"/>
<circle cx="37" cy="50" r="5.6" fill="INK"/>
<circle cx="63" cy="50" r="5.6" fill="INK"/>
<circle cx="38.8" cy="47.8" r="1.9" fill="WHITE" data-d="1"/>
<circle cx="64.8" cy="47.8" r="1.9" fill="WHITE" data-d="1"/>
<path d="M41 64 Q50 72 59 64" stroke="INK" stroke-width="3.4" fill="none" stroke-linecap="round"/>
<ellipse cx="27" cy="62" rx="5" ry="3" fill="CHEEK" opacity=".55" data-d="1"/>
<ellipse cx="73" cy="62" rx="5" ry="3" fill="CHEEK" opacity=".55" data-d="1"/>'''
R["3 vinkje"] = '''
<rect x="11" y="12" width="78" height="76" rx="32" fill="BODY"/>
<rect x="26" y="83" width="18" height="12" rx="6" fill="DARK"/>
<rect x="56" y="83" width="18" height="12" rx="6" fill="DARK"/>
<circle cx="35" cy="42" r="5.6" fill="INK"/>
<circle cx="65" cy="42" r="5.6" fill="INK"/>
<path d="M36 57 L46.5 67 L65 50" stroke="INK" stroke-width="5.4" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
<ellipse cx="22" cy="55" rx="5" ry="3" fill="CHEEK" opacity=".5" data-d="1"/>
<ellipse cx="78" cy="55" rx="5" ry="3" fill="CHEEK" opacity=".5" data-d="1"/>'''
R["4 capsule"] = '''
<line x1="50" y1="15" x2="58" y2="5" stroke="DARK" stroke-width="5" stroke-linecap="round"/>
<circle cx="59.5" cy="5.5" r="4.2" fill="BODY"/>
<rect x="26" y="14" width="48" height="78" rx="24" fill="BODY"/>
<path d="M26 54 H74 V68 A24 24 0 0 1 26 68 Z" fill="DARK" data-d="1"/>
<rect x="34" y="88" width="10" height="9" rx="4.5" fill="DARK"/>
<rect x="56" y="88" width="10" height="9" rx="4.5" fill="DARK"/>
<circle cx="41" cy="37" r="4.8" fill="INK"/>
<circle cx="59" cy="37" r="4.8" fill="INK"/>
<path d="M44 48 Q50 54 56 48" stroke="INK" stroke-width="3" fill="none" stroke-linecap="round"/>
<ellipse cx="34" cy="46" rx="3.6" ry="2.3" fill="CHEEK" opacity=".55" data-d="1"/>
<ellipse cx="66" cy="46" rx="3.6" ry="2.3" fill="CHEEK" opacity=".55" data-d="1"/>'''
R["5 wekkertje"] = '''
<circle cx="25" cy="24" r="12" fill="DARK"/>
<circle cx="75" cy="24" r="12" fill="DARK"/>
<circle cx="50" cy="58" r="35" fill="BODY"/>
<line x1="37" y1="88" x2="33" y2="97" stroke="DARK" stroke-width="6.5" stroke-linecap="round"/>
<line x1="63" y1="88" x2="67" y2="97" stroke="DARK" stroke-width="6.5" stroke-linecap="round"/>
<ellipse cx="39.5" cy="55" rx="4" ry="5.4" fill="INK"/>
<ellipse cx="60.5" cy="55" rx="4" ry="5.4" fill="INK"/>
<path d="M43 67 Q50 73.5 57 67" stroke="INK" stroke-width="3.2" fill="none" stroke-linecap="round"/>
<ellipse cx="30" cy="66" rx="4.5" ry="2.8" fill="CHEEK" opacity=".55" data-d="1"/>
<ellipse cx="70" cy="66" rx="4.5" ry="2.8" fill="CHEEK" opacity=".55" data-d="1"/>'''
R["6 druppel"] = '''
<path d="M50 5 C63 28 83 44 83 66 A33 31 0 0 1 17 66 C17 44 37 28 50 5 Z" fill="BODY"/>
<path d="M20 70 A33 28 0 0 0 80 70 A33 31 0 0 1 20 70 Z" fill="DARK" data-d="1"/>
<ellipse cx="36" cy="94" rx="8.5" ry="4.5" fill="DARK"/>
<ellipse cx="64" cy="94" rx="8.5" ry="4.5" fill="DARK"/>
<ellipse cx="40" cy="64" rx="4" ry="5.3" fill="INK"/>
<ellipse cx="60" cy="64" rx="4" ry="5.3" fill="INK"/>
<path d="M43.5 76 Q50 82 56.5 76" stroke="INK" stroke-width="3.2" fill="none" stroke-linecap="round"/>
<ellipse cx="30" cy="74" rx="4.5" ry="2.8" fill="CHEEK" opacity=".55" data-d="1"/>
<ellipse cx="70" cy="74" rx="4.5" ry="2.8" fill="CHEEK" opacity=".55" data-d="1"/>'''

def fill_tokens(s, mapping):
    for k in sorted(mapping, key=len, reverse=True):
        s = re.sub(rf'(fill|stroke)="{k}"', rf'\1="{mapping[k]}"', s)
    return s

def color_svg(body):
    body = fill_tokens(body, C)
    body = re.sub(r' data-d="1"', "", body)
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="512" height="512">{body}\n</svg>\n'

def mono_svg(body):
    keep = [l for l in body.strip().splitlines() if 'data-d' not in l]
    sil = [l for l in keep if 'INK' not in l]; feat = [l for l in keep if 'INK' in l]
    sil = fill_tokens("\n".join(sil), {k: "#fff" for k in ("BODY", "LIGHT", "DARK", "CHEEK", "WHITE")})
    feat = fill_tokens("\n".join(feat), {"INK": "#000"})
    feat = re.sub(r' opacity="[^"]*"', "", feat)
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="512" height="512">'
            f'<defs><mask id="m" maskUnits="userSpaceOnUse" x="0" y="0" width="100" height="100">{sil}\n{feat}</mask></defs>'
            '<rect width="100" height="100" fill="#000" mask="url(#m)"/></svg>\n')

def ql(svg_path, size, tmp):
    subprocess.run(["qlmanage", "-t", "-s", str(size), "-o", str(tmp), str(svg_path)], capture_output=True)
    return Image.open(tmp / (svg_path.name + ".png")).convert("RGB")

names = list(R)
tmp = Path(tempfile.mkdtemp(dir="/private/tmp/claude-501/-Users-lennar-Desktop-LittleWorks/dc383b77-a415-4cbe-a9b8-201b6d9d3cf8/scratchpad"))
cells = []
for n in names:
    slug = "r" + n.split()[0] + "-" + n.split()[1]
    (OUT / f"{slug}.svg").write_text(color_svg(R[n]))
    (OUT / f"{slug}-mono.svg").write_text(mono_svg(R[n]))
    cells.append((n, ql(OUT / f"{slug}.svg", 300, tmp), ql(OUT / f"{slug}-mono.svg", 36, tmp), ql(OUT / f"{slug}-mono.svg", 18, tmp)))

font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 24)
W, CW, CH = 3 * 340 + 40, 340, 360
sheet = Image.new("RGB", (W, 2 * CH + 2 * 150 + 40), "#F8F7F4"); d = ImageDraw.Draw(sheet)
for i, (n, big, m36, m18) in enumerate(cells):
    x, y = 20 + (i % 3) * CW, 20 + (i // 3) * CH
    sheet.paste(big, (x + 20, y)); d.text((x + 20, y + 312), n, fill="#242424", font=font)
y0 = 2 * CH + 30
for j, (bg, inv) in enumerate([("#F8F7F4", False), ("#242424", True)]):
    yy = y0 + j * 150; d.rectangle([20, yy, W - 20, yy + 135], fill=bg)
    for i, (n, big, m36, m18) in enumerate(cells):
        x = 40 + i * 150
        for im, ox, sc in ((m18, 0, 1), (m36, 30, 1), (m18, 80, 4)):
            a = Image.eval(im.convert("L"), lambda v: 255 - v)
            a = a.resize((im.width * sc, im.height * sc), Image.NEAREST if sc > 1 else Image.BILINEAR)
            ink = Image.new("RGB", a.size, "#fff" if inv else "#000")
            sheet.paste(ink, (x + ox, yy + 20), a)
        d.text((x, yy + 105), n.split()[0], fill="#fff" if inv else "#242424", font=ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 15))
sheet.save(OUT / "richtingen.png"); print("ok")
