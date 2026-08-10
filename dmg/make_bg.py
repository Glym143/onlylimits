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

# --- title with a tiny LED-bar mark ---
tf=font(30); sf=font(14,bold=False)
title="OnlyLimits"
tw=d.textlength(title,font=tf)
mark_w=34
total=mark_w+12+tw
x0=W/2-total/2
# mini bars mark
bx=x0; heights=[10,18,26,34]; bw=6; gap=2; base=52
for i,h in enumerate(heights):
    col=[RED,AMBER,GREEN,GREEN][i]
    d.rounded_rectangle([bx+i*(bw+gap),base-h,bx+i*(bw+gap)+bw,base],radius=2,fill=col)
d.text((x0+mark_w+12, 24), title, font=tf, fill=(240,242,245))
ctext(W/2, 66, "Codex usage limits, right in your menu bar", sf, (150,156,166))

# --- arrow between the app (left) and Applications (right) ---
ay=214
d.line([(250,ay),(392,ay)], fill=(120,150,135), width=6)
d.polygon([(392,ay-16),(392,ay+16),(420,ay)], fill=(120,150,135))

# --- caption ---
ctext(W/2, 356, "Drag  OnlyLimits  into  Applications", font(15,bold=False), (170,176,186))

im.save("dmg/background.png")
# @2x for retina
im.resize((W*2,H*2), Image.LANCZOS).save("dmg/background@2x.png")
print("wrote dmg/background.png", im.size)
