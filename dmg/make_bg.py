#!/usr/bin/env python3
"""Background image for the OnlyLimits .dmg (drag-to-Applications)."""
from PIL import Image, ImageDraw, ImageFont
W,H=640,420
GREEN=(102,181,135); AMBER=(217,168,92); RED=(212,112,112)
TOP=(34,37,47); BOT=(17,19,25)

def font(sz,bold=True):
    for p in (["/System/Library/Fonts/Supplemental/Arial Bold.ttf"] if bold else
              ["/System/Library/Fonts/Supplemental/Arial.ttf"])+["/System/Library/Fonts/Helvetica.ttc"]:
        try: return ImageFont.truetype(p,sz)
        except Exception: pass
    return ImageFont.load_default()

im=Image.new("RGB",(W,H)); d=ImageDraw.Draw(im)
for y in range(H):
    t=y/H; d.line([(0,y),(W,y)],fill=tuple(int(TOP[i]*(1-t)+BOT[i]*t) for i in range(3)))

def ctext(cx,y,txt,f,fill):
    w=d.textlength(txt,font=f); d.text((cx-w/2,y),txt,font=f,fill=fill)

# --- title with the real app icon ---
tf=font(30); sf=font(14,bold=False)
title="OnlyLimits"
tw=d.textlength(title,font=tf)
icon=Image.open("icon/icon_1024.png").convert("RGBA").resize((46,46), Image.LANCZOS)
gap_i=14
total=icon.width+gap_i+tw
x0=int(W/2-total/2)
title_y=24
im.paste(icon, (x0, title_y-8), icon)                 # real icon, alpha-composited
d.text((x0+icon.width+gap_i, title_y), title, font=tf, fill=(240,242,245))
ctext(W/2, 66, "Codex usage limits, right in your menu bar", sf, (150,156,166))

# --- arrow between the app (left) and Applications (right) ---
# Icons are centered at x=160 and x=480 at 128px, so their inner edges are ~224
# and ~416. Keep equal 32px margins on both sides -> arrow spans 256..384.
ay=214
d.line([(256,ay),(360,ay)], fill=(120,150,135), width=6)
d.polygon([(360,ay-16),(360,ay+16),(384,ay)], fill=(120,150,135))

# --- caption ---
ctext(W/2, 356, "Drag  OnlyLimits  into  Applications", font(15,bold=False), (170,176,186))

im.save("dmg/background.png")
# @2x for retina
im.resize((W*2,H*2), Image.LANCZOS).save("dmg/background@2x.png")
print("wrote dmg/background.png", im.size)
