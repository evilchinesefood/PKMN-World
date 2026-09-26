#!/usr/bin/env python3
"""Render native screenshots and lossless animation clips from completed runs."""
import argparse
import hashlib
import html
import json
from pathlib import Path
import re
import shutil
from PIL import Image, ImageChops

p = argparse.ArgumentParser()
p.add_argument('--runs', type=Path, required=True)
p.add_argument('--out', type=Path, required=True)
p.add_argument('--before-source', required=True)
p.add_argument('--after-source', required=True)
a = p.parse_args()
manifest = {'before_source': a.before_source, 'after_source': a.after_source, 'media': [], 'comparisons': [], 'checks': {}}


def validate_verdict(run):
    """Require a positive finished run and its matching, non-failed sentinel."""
    directory = a.runs / run
    logs = [path for path in directory.glob('*.log') if path.name != 'runner.log']
    if len(logs) != 1:
        raise ValueError(f'{run}: exactly one suite log required')
    lines = logs[0].read_text(encoding='utf-8').strip().splitlines()
    verdict = re.fullmatch(r'VERDICT ([^:]+): (\d+)/(\d+) PASS', lines[-1] if lines else '')
    if not verdict or not (int(verdict[2]) == int(verdict[3]) > 0):
        raise ValueError(f'{run}: positive complete PASS required')
    label, count = verdict[1], int(verdict[2])
    sentinel = directory / f'{label}.PASS'
    if not sentinel.is_file() or (directory / f'{label}.FAIL').exists():
        raise ValueError(f'{run}: current PASS sentinel required without FAIL')
    stamp = sentinel.read_text(encoding='utf-8').strip()
    if not re.fullmatch(rf'PASS {count}/{count} rom=[A-Fa-f0-9]{{32,40}} at=\S+ suite={re.escape(label)}', stamp):
        raise ValueError(f'{run}: sentinel must match the completed verdict')
    # A hash/ROM-name guard can abort before lib.lua opens its suite log. In
    # that case run_fixture.py still writes a fresh runner log: reject the old
    # suite log and PASS left beside the new, aborted run.
    runner = directory / 'runner.log'
    if runner.exists() and lines[-1] not in runner.read_text(encoding='utf-8').splitlines():
        raise ValueError(f'{run}: runner did not report this completed verdict')
    return label, count


baseline_label, baseline_count = validate_verdict('before')
manifest['baseline_checks'] = {baseline_label: baseline_count}
for run in ('after', 'HubSpritesServices', 'HubSpritesOutfits', 'HubSpritesReadability', 'save', 'delivery'):
    label, count = validate_verdict(run)
    manifest['checks'][label] = count
targeted_checks = sum(manifest['checks'].values())
media = a.out / 'media'
media.mkdir(parents=True, exist_ok=True)


def one(run, pattern):
    """Require an unambiguous capture; stale or missing output is an error."""
    paths = list((a.runs / run).glob(pattern))
    if len(paths) != 1:
        raise ValueError(f'{run}/{pattern}: expected one capture, found {len(paths)}')
    return paths[0]


def picture(run, pattern, caption, wide=False):
    """Copy the native pixels and record their originating run and hash."""
    path = one(run, pattern)
    with Image.open(path) as im:
        assert im.size == (240, 160), path
    name = run + '_' + path.name
    dest = media / name
    shutil.copy2(path, dest)
    manifest['media'].append({'path': 'media/' + name, 'run': run, 'capture': path.name,
                              'sha256': hashlib.sha256(dest.read_bytes()).hexdigest()})
    cls = 'screen' if wide else 'thumb'
    return (f'<figure><a href="media/{name}"><img class="{cls}" src="media/{name}" '
            f'width="240" height="160" loading="lazy" alt="{html.escape(caption)}"></a>'
            f'<figcaption>{html.escape(caption)}</figcaption></figure>')


def animation(run, actor):
    """Encode the facing/walking/shadow fixture at its sampled game timing."""
    paths = []
    for action in ('walk', 'return', 'shadow'):
        paths.extend(sorted((a.runs / run).glob(f'clip_{actor}_{action}_*.png')))
    assert len(paths) == 28, (run, actor, len(paths))
    frames = [Image.open(path).convert('RGB') for path in paths]
    durations = [round((i + 1) * 4000 / 60) - round(i * 4000 / 60) for i in range(len(frames))]
    name = f'{run}_{actor}_motion.webp'
    dest = media / name
    frames[0].save(dest, save_all=True, append_images=frames[1:], duration=durations,
                   loop=0, lossless=True, method=6)
    # WebP may coalesce duplicate frames. Verify each decoded frame against its
    # source timestamp and the total duration, rather than assuming frame counts.
    with Image.open(dest) as clip:
        elapsed = 0
        for i in range(clip.n_frames):
            clip.seek(i)
            decoded = clip.convert('RGB')
            duration = clip.info['duration']
            starts = [sum(durations[:j]) for j in range(len(frames))]
            for j, start in enumerate(starts):
                if elapsed <= start < elapsed + duration:
                    assert ImageChops.difference(decoded, frames[j]).getbbox() is None
            elapsed += duration
        assert elapsed == sum(durations)
    manifest['media'].append({'path': 'media/' + name, 'run': run,
        'source_frames': [path.name for path in paths], 'duration_ms': sum(durations),
        'sha256': hashlib.sha256(dest.read_bytes()).hexdigest()})
    return f'<figure><img class="screen" src="media/{name}" width="240" height="160" alt="{actor} {run} walking and shadow"><figcaption>{run.title()} · walking, return, jump shadow</figcaption></figure>'


for before in sorted((a.runs / 'before').glob('HubSpritesComparison_*.png')):
    after = a.runs / 'after' / before.name
    diff = ImageChops.difference(Image.open(before).convert('RGB'), Image.open(after).convert('RGB'))
    manifest['comparisons'].append({'capture': before.name, 'changed_bounds': diff.getbbox(),
                                   'changed_pixels': sum(pixel != (0, 0, 0) for pixel in diff.getdata())})
assert len(manifest['comparisons']) == 11
assert manifest['comparisons'][-1]['changed_pixels'] == 0, 'nurse/Chansey scene must be unchanged'

parts = ['''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Pokémon World · Hub sprites #330</title><style>
:root{--zoom:2;color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#101821;color:#ebf2f7;font:16px/1.55 system-ui,sans-serif}main{max-width:1150px;margin:auto;padding:28px}h1{font-size:30px;line-height:1.2}h2{font-size:23px;margin-top:34px}p{max-width:880px;color:#c1ced8}a{color:#9cddff}button{font:inherit;color:inherit;border:1px solid #657c90;background:#233746;border-radius:6px;padding:5px 14px;cursor:pointer}button[aria-pressed=true]{background:#345f67;border-color:#8bd5c8}.bar{display:flex;gap:8px;align-items:center;position:sticky;top:0;padding:10px 0;background:#101821ed;z-index:1}.pair,.grid{display:flex;gap:18px;flex-wrap:wrap;align-items:start}.pair{overflow-x:auto;flex-wrap:nowrap}.grid{gap:14px}figure{margin:0 0 16px}img{display:block;image-rendering:pixelated;background:#080c10}.screen{width:calc(240px * var(--zoom));height:calc(160px * var(--zoom));max-width:none}.thumb{width:240px;height:160px}figcaption{font-size:13px;color:#b8c6d0;margin-top:7px;max-width:460px}.badge{display:inline-block;padding:3px 10px;background:#254b45;border-radius:5px;color:#b5eee0;font-size:14px;margin:0 8px 8px 0}details{border-top:1px solid #344753;margin-top:22px;padding-top:16px}summary{font-weight:650;cursor:pointer;margin-bottom:18px}footer{font-size:13px;margin-top:36px;overflow-wrap:anywhere}#delivery{border:1px solid #496b6c;padding:18px;border-radius:9px}.small{font-size:14px}code{color:#d9e8e9}@media(max-width:600px){main{padding:16px}h1{font-size:25px}}
</style><main><h1>World Hub: matching NPC artwork</h1>
<p>The harbor master and curator now use the FRLG sheets already bundled with the game, matching the Hub’s room art, nurse and attendants. These are the only two game-data changes.</p>
<span class="badge">50/50 tracked suites pass</span><span class="badge">All outfits + small / large / shiny followers checked</span>
<p><strong>Quick review:</strong> compare the two characters below, then watch their movement. Expand the later sections for the full direction, outfit and environment samples.</p>
<div id="delivery" hidden><strong>Ready-to-play build</strong><p><a id="download">Download ROM + prepared save</a></p><p class="small">Open the included ROM with its matching save. You start near the harbor master with Pichu. Talk to him, walk around the left end of the counter to the curator’s north side and talk facing down, then walk past the nurse at the lower central counter. B declines the curator’s repeat-tour offer. This short route was verified on the unmodified ROM.</p></div>
<div class="bar">Pixel scale <button data-scale="1" aria-pressed="false">Native</button><button data-scale="2" aria-pressed="true">2×</button><button data-scale="3" aria-pressed="false">3×</button></div>''']
for actor, title in [('harbor', 'Harbor master'), ('curator', 'Charm curator')]:
    parts.append(f'<h2>{title}</h2><div class="pair">')
    for run in ('before', 'after'):
        parts.append(picture(run, f'*_{actor}_default.png', run.title() + ' · ordinary map-facing direction', True))
    parts.append('</div><div class="pair">')
    for run in ('before', 'after'):
        parts.append(animation(run, actor))
    parts.append('</div>')
parts.append('<details><summary>All four directions · matched before/after</summary>')
for actor in ('harbor', 'curator'):
    for d, direction in [(1, 'down'), (2, 'up'), (3, 'left'), (4, 'right')]:
        parts.append('<div class="pair">')
        for run in ('before', 'after'):
            parts.append(picture(run, f'*_{actor}_facing_{d}.png', f'{actor.title()} · {direction} · {run}'))
        parts.append('</div>')
parts.append('</details><details><summary>Nurse and Chansey · pixel-identical control scene</summary><div class="pair">')
for run in ('before', 'after'):
    parts.append(picture(run, '*_nurse_and_chansey.png', run.title() + ' · 0 changed pixels', True))
parts.append('</div></details><details><summary>All 12 player outfits + representative entry/menu returns</summary><div class="grid">')
colors = ['red', 'blue', 'green', 'purple', 'black', 'pink']
for outfit in range(12):
    parts.append(picture('HubSpritesOutfits', f'*_outfit_{outfit}_curator.png',
                         ('May' if outfit >= 6 else 'Brendan') + ' · ' + colors[outfit % 6]))
for outfit in (0, 11):
    for hour in (12, 22):
        parts.append(picture('HubSpritesOutfits', f'*_outfit_{outfit:02d}_west_{hour:02d}h_return.png',
                             f'Outfit {outfit} · actual west stairs · {hour}:00 · after menu'))
parts.append('</div></details><details><summary>Service and intro samples · three follower variants</summary><p>All nine tour stops and all 16 service approaches were traversed with Pichu, Snorlax and shiny Snorlax. All fourteen NPCs were visibly sampled across the route; the camera does not load every map event at once.</p><div class="grid">')
for follower in ('pichu', 'snorlax', 'shiny_snorlax'):
    for scene in ('tour_1', 'tour_9', 'harbor', 'curator', 'nurse', 'battle_depot'):
        parts.append(picture('HubSpritesServices', f'HubSpritesServices_??_{follower}_{scene}.png', (follower + ' · ' + scene).replace('_', ' ')))
parts.append('</div></details><details><summary>Route 35 and National Park readability · day/night</summary><p>These maps and placements are unchanged. Captions name authored anchors; runtime coordinates and visibility are recorded in the actor CSVs. Moving Pokémon can leave their anchor. Day/night hide flags remain active.</p><div class="grid">')
for target in ('Route35_10_39', 'Route35_12_16', 'Route35_12_19', 'Route35_26_16', 'Route35_28_9', 'Route35_32_45', 'Park_14_47', 'Park_25_44', 'Park_29_44', 'Park_26_47'):
    for hour in (12, 22):
        parts.append(picture('HubSpritesReadability', f'*_{target}_follower1_{hour:02d}h.png',
                             f'{target.replace("_", " ")} · Snorlax · {hour}:00'))
parts.append(f'</div></details><details><summary>Engineering evidence and provenance</summary><p>{targeted_checks:,} targeted checks pass, plus 50 tracked suites. Development and release configurations build; all content validators retain their baseline. The local playtest package uses the tested development configuration required by RELEASING.md.</p><p><a href="../evidence/validation.md">Validation record and limits</a> · <a href="../README.md">Reproduction commands</a> · <a href="capture-sources.json">Capture hashes and pixel differences</a></p></details>')
parts.append(f'<footer>Before source: <code>{html.escape(a.before_source)}</code><br>After game source: <code>{html.escape(a.after_source)}</code><br>Native 240×160 screenshots. Only nearest-neighbor integer enlargement. Animation fixtures temporarily turn, walk and jump the two NPCs; those fixture actions are absent from the delivered ROM.</footer>')
parts.append('''</main><script>
for(const button of document.querySelectorAll('[data-scale]'))button.addEventListener('click',()=>{document.documentElement.style.setProperty('--zoom',button.dataset.scale);for(const other of document.querySelectorAll('[data-scale]'))other.setAttribute('aria-pressed',String(other===button));});
fetch('../delivery.json').then(r=>r.ok?r.json():null).then(d=>{if(d&&/^[A-Za-z0-9.-]+\\.zip$/.test(d.file)){document.querySelector('#download').href='../'+d.file;document.querySelector('#delivery').hidden=false;}}).catch(()=>{});
</script></html>''')
(a.out / 'index.html').write_text('\n'.join(parts), encoding='utf-8')
(a.out / 'capture-sources.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
print(f'{len(manifest["media"])} media; {len(manifest["comparisons"])} matched comparisons')
