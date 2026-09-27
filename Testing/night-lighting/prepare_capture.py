#!/usr/bin/env python3
"""Choose reproducible public viewpoints and generate disposable capture fixtures."""
import json
from pathlib import Path
import sys

from assets import Assets

root = Path(sys.argv[1])
a = Assets(root)
folder = Path(__file__).resolve().parent
scenes = []
for name, layout in sorted(a.towns.items()):
    words = a.words(layout)
    w,h = layout['width'],layout['height']
    objects = {(o['x'],o['y']) for o in a.maps[name].get('object_events',[])}
    warps = {(o['x'],o['y']) for o in a.maps[name].get('warp_events',[])}
    candidates = []
    cache = {}
    for i, word in enumerate(words):
        mid = word&1023
        if mid not in cache:
            cache[mid] = bool(a.render(layout,mid,True).getbbox())
        if not cache[mid]: continue
        tx,ty = i%w,i//w
        for dy in [3,2,4]:
            for dx in [0,-1,1]:
                x,y = tx+dx,ty+dy
                if not (2<=x<w-2 and 2<=y<h-2):continue
                if (x,y) in objects|warps or words[y*w+x]&0xC00:continue
                score = abs(x-w//2)+abs(y-h//2)+abs(dx)*3+abs(dy-3)*2
                candidates.append((score,x,y))
    if not candidates:
        for i,word in enumerate(words):
            x,y=i%w,i//w
            if 2<=x<w-2 and 2<=y<h-2 and not word&0xC00 and (x,y) not in objects|warps:
                candidates.append((abs(x-w//2)+abs(y-h//2),x,y))
    _,x,y=min(candidates)
    scenes.append({'name':name,'map':a.maps[name]['id'],'x':x,'y':y,'region':layout['layout_version']})
base=(root/'Testing/warm-windows/fixture.c').read_text()
start=base.index('        static const struct {')
end=base.index('        if (arg < ARRAY_COUNT(scenes))',start)
rows=''.join('            {%s, %d, %d},\n'%(s['map'],s['x'],s['y']) for s in scenes)
base=base[:start]+'        static const struct { u16 map; s8 x, y; } scenes[] =\n        {\n'+rows+'        };\n'+base[end:]
(folder/'fixture.c').write_text(base)
(folder/'scenes.json').write_text(json.dumps(scenes,indent=2)+'\n')
(folder/'scenes.lua').write_text('return {\n'+''.join('  {"%s",%d,%d},\n'%(s['name'],s['x'],s['y']) for s in scenes)+'}\n')
print(f'{len(scenes)} town viewpoints.')
