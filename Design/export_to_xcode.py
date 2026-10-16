"""Zet de assets in de Xcode-assetcatalogus van Tikk. Run: python3 export_to_xcode.py"""
import json, shutil
from pathlib import Path
from PIL import Image
import make_assets as a
import make_wereld20 as w

CAT = Path(__file__).parent.parent / "Apps" / "Tikk" / "Resources" / "Assets.xcassets"
if CAT.exists(): shutil.rmtree(CAT)
CAT.mkdir(parents=True)
INFO = {"author": "xcode", "version": 1}
def wj(path, obj): path.mkdir(parents=True, exist_ok=True); (path / "Contents.json").write_text(json.dumps(obj, indent=2))
wj(CAT, {"info": INFO})

def color(hexv):
    r, g, b = (int(hexv[i:i+2], 16) / 255 for i in (1, 3, 5))
    return {"color-space": "srgb", "components": {"red": f"{r:.3f}", "green": f"{g:.3f}", "blue": f"{b:.3f}", "alpha": "1.000"}}
def colorset(name, light, dark=None):
    entries = [{"idiom": "universal", "color": color(light)}]
    if dark: entries.append({"idiom": "universal", "appearances": [{"appearance": "luminosity", "value": "dark"}], "color": color(dark)})
    wj(CAT / f"{name}.colorset", {"colors": entries, "info": INFO})
colorset("AccentColor", "#FF8A4C")                      # Tikk Orange
colorset("BrandBackground", "#F8F7F4", "#242424")        # Warm Off-White / Soft Black
colorset("BrandInk", "#242424", "#F8F7F4")
colorset("BrandMuted", "#969696")
colorset("BrandGreen", "#91B89A")

def imageset(name, files, template=False):
    """files: lijst van (bestandsnaam, scale, dark?) — bronpad is een PIL-image of Path."""
    d = CAT / f"{name}.imageset"; d.mkdir(parents=True)
    imgs = []
    for fn, scale, dark, src in files:
        (src.save(d / fn) if isinstance(src, Image.Image) else shutil.copy(src, d / fn))
        e = {"idiom": "universal", "filename": fn, "scale": f"{scale}x"}
        if dark: e["appearances"] = [{"appearance": "luminosity", "value": "dark"}]
        imgs.append(e)
    obj = {"images": imgs, "info": INFO}
    if template: obj["properties"] = {"template-rendering-intent": "template"}
    wj(d, obj)

# App-icoon
shutil.copytree(a.ROOT / "AppIcon" / "tikk" / "AppIcon.appiconset", CAT / "AppIcon.appiconset")

# Menubalk (template). idle = idle-1 (statisch), tracking = 5 frames
B = a.ROOT / "Menubalk-hoofd" / "met-stralen"
imageset("MenuIdle", [("MenuIdle.png", 1, False, B / "idle-1.png"), ("MenuIdle@2x.png", 2, False, B / "idle-1@2x.png")], template=True)
for i in range(1, 6):
    imageset(f"MenuTracking{i}", [(f"MenuTracking{i}.png", 1, False, B / f"tracking-{i}.png"), (f"MenuTracking{i}@2x.png", 2, False, B / f"tracking-{i}@2x.png")], template=True)

# Poses (kleur, pixel-art: 1x = 20 px, 2x = 40 px)
poses = {"TikkMaster": a.POSES["tikk-hoofdfiguur"], "TikkLeeg": a.POSES["tikk-lege-staat"], "TikkKlaar": a.POSES["tikk-klaar"],
         "TikkOeps": a.POSES["tikk-oeps"], "TikkSlaap": a.POSES["tikk-slaap"],
         "TikkWerkA": w.FIG["tikk-werk-a"][0], "TikkWerkB": w.FIG["tikk-werk-b"][0]}
for n, g in poses.items():
    imageset(n, [(f"{n}.png", 1, False, a.render(g, a.TP, 1)), (f"{n}@2x.png", 2, False, a.render(g, a.TP, 2))])

# Woordmerk (licht + donker, 1x/2x/3x)
for sc in (1, 2, 3): pass
W_ = a.ROOT / "Woordmerk"; sfx = lambda sc: "" if sc == 1 else f"@{sc}x"
imageset("WordmarkTikk", [(f"wm{sfx(sc)}.png".replace("@", "-").replace("wm-", "wm@") if False else f"wm{('@%dx' % sc) if sc > 1 else ''}.png", sc, False, W_ / f"tikk-licht{sfx(sc)}.png") for sc in (1, 2, 3)]
        + [(f"wm-dark{('@%dx' % sc) if sc > 1 else ''}.png", sc, True, W_ / f"tikk-donker{sfx(sc)}.png") for sc in (1, 2, 3)])

# Onboarding (40x26 art-pixels)
for i, (n, g) in enumerate(a.ONB.items(), 1):
    g = ["".join(r) for r in g]
    imageset(f"Onboarding{i}", [(f"o{i}.png", 1, False, a.render(g, a.TP, 1)), (f"o{i}@2x.png", 2, False, a.render(g, a.TP, 2))])
print("ok", sorted(p.name for p in CAT.iterdir()))
