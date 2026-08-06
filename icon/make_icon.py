#!/usr/bin/env python3
"""Generates OnlyLimits' pixel-art LED-meter app icon (1024px master)."""
from PIL import Image, ImageDraw

S = 1024
GREEN=(102,181,135); AMBER=(217,168,92); RED=(212,112,112)
TOP=(34,37,47); BOT=(17,19,25)
UNLIT=(48,52,63)

def color_for(frac):
    return RED if frac < 0.34 else AMBER if frac < 0.62 else GREEN

def build():
    img=Image.new('RGBA',(S,S),(0,0,0,0)); d=ImageDraw.Draw(img)
    # vertical gradient background
    for y in range(S):
        t=y/S
        c=tuple(int(TOP[i]*(1-t)+BOT[i]*t) for i in range(3))
        d.line([(0,y),(S,y)], fill=c+(255,))
    # LED bars (crisp squares = pixel look)
    cols,rows=4,8
    x0,x1,y0,y1=168,856,196,828
    cw=124; gx=(x1-x0-cols*cw)/(cols-1)
    ch=62;  gy=(y1-y0-rows*ch)/(rows-1)
    heights=[2,4,6,8]
    for c in range(cols):
        cx=x0+c*(cw+gx); frac=heights[c]/rows; col=color_for(frac)
        for r in range(rows):
            cy=y1-ch-r*(ch+gy)
            box=[round(cx),round(cy),round(cx+cw),round(cy+ch)]
            if r < heights[c]:
                d.rectangle(box, fill=col+(255,))
                # subtle top highlight for a chunky LED feel
                d.rectangle([box[0],box[1],box[2],box[1]+6],
                            fill=tuple(min(255,int(v*1.25)) for v in col)+(255,))
            else:
                d.rectangle(box, fill=UNLIT+(255,))
    # smooth rounded-rect mask (hi-res -> downscale) so corners aren't jagged
    sc=4; m=Image.new('L',(S*sc,S*sc),0)
    ImageDraw.Draw(m).rounded_rectangle([0,0,S*sc-1,S*sc-1], radius=185*sc, fill=255)
    img.putalpha(m.resize((S,S), Image.LANCZOS))
    return img

if __name__=='__main__':
    build().save('icon/icon_1024.png')
    print('wrote icon/icon_1024.png')
