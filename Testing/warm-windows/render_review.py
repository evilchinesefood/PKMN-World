#!/usr/bin/env python3
"""Require completed runs, compare native frames/palettes, publish a small review."""
import argparse
import hashlib
import html
import json
from pathlib import Path
import re
import shutil
import struct

from PIL import Image, ImageChops

SCENES = ['new_bark', 'cherrygrove_west', 'cherrygrove_middle', 'cherrygrove_east',
          'route30_north', 'route30_south', 'route29', 'route27', 'route31', 'route46']
TIMES = ['noon', 'dusk', 'night', 'dawn']
CLIPS = {'sweep_dusk': (9, 700), 'sweep_dawn': (9, 700),
         'natural_dusk': (100, 40), 'natural_dawn': (100, 40),
         'menu': (10, 100), 'house_entry': (15, 100), 'house_exit': (15, 100),
         'battle_return': (30, 100), 'connection_out': (10, 100), 'connection_back': (15, 100)}


def passed(directory, md5=None):
    logs = [p for p in directory.glob('*.log') if p.name != 'runner.log']
    assert len(logs) == 1, f'{directory}: one suite log required'
    lines = logs[0].read_text().strip().splitlines()
    verdict = re.fullmatch(r'VERDICT ([^:]+): (\d+)/(\d+) PASS', lines[-1] if lines else '')
    assert verdict and int(verdict[2]) == int(verdict[3]) > 0, f'{directory}: complete positive verdict required'
    label, count = verdict[1], int(verdict[2])
    assert not list(directory.glob('*.FAIL')), f'{directory}: failed run'
    stamp = (directory/f'{label}.PASS').read_text().strip()
    match = re.fullmatch(rf'PASS {count}/{count} rom=([A-Fa-f0-9]{{32,40}}) at=\S+ suite={label}', stamp)
    assert match and (md5 is None or match[1].lower() == md5.lower()), f'{directory}: mismatched sentinel'
    runner = (directory/'runner.log').read_text().strip().splitlines()
    if runner[-2:] == ['---', 'exit code: 0']:
        runner = runner[:-2]
    assert runner and runner[-1] == lines[-1], f'{directory}: fresh terminal runner verdict required'
    return count


def native(path):
    image = Image.open(path).convert('RGB')
    assert image.size == (240, 160), path
    return image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runs', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--before-source', required=True)
    parser.add_argument('--after-source', required=True)
    parser.add_argument('--delivery-md5', required=True)
    parser.add_argument('--atlas', type=Path, required=True)
    args = parser.parse_args()
    # Preflight every run before copying any evidence into the publication.
    counts = {name: passed(args.runs/name, args.delivery_md5 if name=='delivery' else None)
              for name in ('before', 'after', 'before-lifecycle', 'after-lifecycle', 'delivery')}
    args.out.mkdir(parents=True, exist_ok=True)
    shutil.copy2(args.atlas, args.out/'palette-atlas.png')
    media = args.out/'media'
    media.mkdir(exist_ok=True)
    manifest = {'before_source': args.before_source, 'after_source': args.after_source,
                'checks': counts, 'comparisons': [], 'clips': {}}
    cards = []
    for n, scene in enumerate(SCENES):
        rows = []
        for t, time in enumerate(TIMES):
            tag = scene+'_'+time
            name = f'WarmWindowsCapture_{n*4+t+1:02}_{tag}.png'
            before, after = [native(args.runs/side/name) for side in ('before','after')]
            pals = [struct.unpack('<256H', (args.runs/side/f'{tag}.pal').read_bytes()) for side in ('before','after')]
            changed = [i for i in range(256) if pals[0][i] != pals[1][i]]
            assert changed == ([] if time=='noon' else [136,137,138]), (tag,changed)
            count = 0
            for p0,p1 in zip(before.getdata(),after.getdata()):
                if p0 != p1:
                    count += 1
            if time=='noon' or n>=6:
                assert count == 0, f'{tag}: expected identical pixels, found {count}'
            else:
                assert count > 0, f'{tag}: intended window never changed'
                # Every altered screen pixel must be one of the three changed
                # glass colors, in both the before and after hardware palettes.
                def rgb(v):
                    return tuple((channel<<3)|(channel>>2) for shift in (0,5,10)
                                 for channel in [(v>>shift)&31])
                pairs = {(rgb(pals[0][i]),rgb(pals[1][i])) for i in changed}
                assert all((p0,p1) in pairs for p0,p1 in zip(before.getdata(),after.getdata()) if p0!=p1), tag
            manifest['comparisons'].append({'scene':tag,'changed_pixels':count,'changed_palette_entries':changed})
            for side in ('before','after'):
                shutil.copy2(args.runs/side/name,media/f'{side}_{tag}.png')
            rows.append(f'<div><h4>{time.title()}</h4><div class="pair"><figure><img src="media/before_{tag}.png"><figcaption>Before</figcaption></figure><figure><img src="media/after_{tag}.png"><figcaption>After · {count} pixels changed</figcaption></figure></div></div>')
        cards.append(f'<details><summary>{scene.replace("_"," ").title()}</summary>{"".join(rows)}</details>')
    for tag,(count,duration) in CLIPS.items():
        frames = [native(args.runs/'after-lifecycle'/f'{tag}_{i:03}.png') for i in range(1,count+1)]
        destination = media/f'{tag}.webp'
        # Reuse an existing clip only after the same full decode comparison
        # below. A stale or partial clip fails validation; remove it to rebuild.
        if not destination.exists():
            frames[0].save(destination,format='WEBP',save_all=True,append_images=frames[1:],
                           duration=duration,loop=0,lossless=True,quality=100,method=6)
        # WebP coalesces identical consecutive frames. Expand by their durations
        # and verify each decoded frame against the native source sequence.
        decoded = Image.open(destination)
        elapsed = 0
        for i in range(decoded.n_frames):
            decoded.seek(i)
            frame = decoded.convert('RGB')
            segment = decoded.info['duration']
            assert segment % duration == 0
            for _ in range(segment//duration):
                assert ImageChops.difference(frame,frames[elapsed//duration]).getbbox() is None, tag
                elapsed += duration
        assert elapsed == count*duration
        manifest['clips'][tag] = {'source_frames':count,'duration_ms':elapsed,
                                 'sha256':hashlib.sha256(destination.read_bytes()).hexdigest()}
    (args.out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    styles = 'body{background:#101d2b;color:#e3edf3;font:16px system-ui;max-width:1100px;margin:32px auto;padding:0 20px}a{color:#8ed4ff}img{image-rendering:pixelated;width:480px;max-width:100%;height:auto}figure{margin:8px 0}figcaption{color:#aac2d4}h1{font-size:28px}.pair,.clips{display:flex;gap:20px;flex-wrap:wrap}details{border-top:1px solid #385268;padding:16px 0}summary{cursor:pointer;font-weight:bold}p{max-width:850px;line-height:1.5}'
    clips = ''.join(f'<figure><img src="media/{tag}.webp"><figcaption>{label}</figcaption></figure>' for tag,label in (
        ('sweep_dusk','19:00–21:00 · 15-minute samples'),('sweep_dawn','06:00–10:00 · 30-minute samples')))
    returns = ''.join(f'<figure><img loading="lazy" src="media/{tag}.webp"><figcaption>{tag.replace("_"," ").title()}</figcaption></figure>' for tag in CLIPS if not tag.startswith('sweep'))
    document = f'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Pokémon World · warm Johto windows</title><style>{styles}</style><h1>Warm Johto windows · #335</h1>
<p>Six small glass panes become amber at night. Daytime and the four neighboring maps remain pixel-identical. Only three colors change; the pink trees, buildings and terrain retain their existing lighting.</p>
<p><a href="../PokemonWorld-WarmWindows-{html.escape(args.after_source[:10])}.zip" download>Download game + prepared save</a> · <a href="manifest.json">Verification results</a> · <a href="../README.txt">5-minute playtest route</a></p>
<p>The existing engine already gives protected glass a pale cream light at night. This change warms it further with the approved amber palette. The surrounding windows that use other palettes are outside this six-pane pilot.</p>
<h2>Quick look</h2><div class="pair"><figure><img src="media/before_cherrygrove_west_night.png"><figcaption>Before · night</figcaption></figure><figure><img src="media/after_cherrygrove_west_night.png"><figcaption>After · night, pink trees unchanged</figcaption></figure></div>
<h2>Dusk and dawn</h2><div class="clips">{clips}</div><p>These time-lapses set the clock between samples. The natural-clock clips below separately verify both boundaries while standing still.</p>
<h2>All six panes and four unaffected maps</h2><p>Noon 12:00 · dusk midpoint 20:00 · full night 22:00 · dawn midpoint 08:00. Images are native 240×160, displayed at 2× with nearest-neighbor scaling.</p>{''.join(cards)}
<details><summary>Palette atlas, including unused metatiles</summary><p>Source tiles before runtime lighting. The unused rock metatile keeps its colors.</p><img src="palette-atlas.png" alt="Four source metatiles with day and alternate palettes"></details>
<details><summary>Return flows and natural clock progression</summary><p>Natural clock clips cover 200 emulated seconds at 50× playback. Other return clips play at normal speed.</p><div class="clips">{returns}</div></details>
<p>Before source: <code>{html.escape(args.before_source)}</code><br>After source: <code>{html.escape(args.after_source)}</code>. {sum(counts.values())} focused assertions pass. The download is the unmodified, tested development build required by RELEASING.md; fixture hooks are only in disposable capture ROMs.</p></html>'''
    (args.out/'index.html').write_text(document)
    print(f'PASS: {len(manifest["comparisons"])} native before/after comparisons; {len(CLIPS)} decoded lossless clips; {sum(counts.values())} runtime assertions.')


if __name__ == '__main__':
    main()
