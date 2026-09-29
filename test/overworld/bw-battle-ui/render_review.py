#!/usr/bin/env python3
"""Publish unchanged native screenshots and lossless clips from completed suites."""
import argparse
import hashlib
import html
import json
import re
import shutil
from pathlib import Path
from PIL import Image

p = argparse.ArgumentParser()
p.add_argument('--after', type=Path, required=True)
p.add_argument('--before', type=Path, required=True)
p.add_argument('--sweep', type=Path, required=True)
p.add_argument('--out', type=Path, required=True)
a = p.parse_args()
media = a.out / 'evidence/review'
media.mkdir(parents=True, exist_ok=True)
provenance = []

def one(folder, pattern, name):
    files = sorted(folder.glob(pattern))
    assert len(files) == 1, (folder, pattern, files)
    src = files[0]
    target = media / (name + '.png')
    shutil.copy2(src, target)
    provenance.append({'path': str(target.relative_to(a.out)), 'source': str(src),
                       'sha256': hashlib.sha256(target.read_bytes()).hexdigest()})
    return 'evidence/review/' + target.name

def clip(folder, pattern, name, duration):
    files = sorted(folder.glob(pattern), key=lambda f: int(re.search(r'_(\d+)_', f.name)[1]))
    assert files, (folder, pattern)
    target = media / (name + '.webp')
    frames = []
    for f in files:
        with Image.open(f) as source:
            assert source.size == (240, 160), f
            frames.append(source.convert('RGB'))
    frames[0].save(target, save_all=True, append_images=frames[1:],
                   duration=round(duration * 1000), loop=0, lossless=True, method=6)
    provenance.append({'path': str(target.relative_to(a.out)), 'frames': [str(f) for f in files],
                       'seconds_per_sample': duration, 'sha256': hashlib.sha256(target.read_bytes()).hexdigest()})
    return 'evidence/review/' + target.name

sections = []
def card(title, src, text=''):
    return '<figure><img loading="lazy" src="' + src + '" alt="' + html.escape(title) + '"><figcaption><b>' + html.escape(title) + '</b><p>' + html.escape(text) + '</p></figcaption></figure>'
def section(title, cards, text='', section_id=None):
    anchor = ' id="' + html.escape(section_id, quote=True) + '"' if section_id else ''
    sections.append('<section' + anchor + '><h2>' + html.escape(title) + '</h2><p>' + html.escape(text) + '</p><div class="grid">' + ''.join(cards) + '</div></section>')
def compare(name, pattern, title):
    before = one(a.before, pattern, 'before-' + name)
    after = one(a.after/'capture', pattern, name)
    section(title, [card('Before', before), card('BW', after)])

compare('commands', '*_commands.png', '1. Command panel')
compare('moves', '*_moves.png', '2. Move names, PP and effectiveness')
section('3. L-button move information — original window preserved', [
    card('Original World window', one(a.before, '*_move_details.png', 'before-details')),
    card('BW with the original World window', one(a.after/'capture', '*_move_details.png', 'details'))],
    'The existing rounded SwSh frame and text layout are retained. The move grid and healthboxes use BW.', 'move-info')
section('Long names and unusual slots', [
    card('Complete long move names', one(a.after/'regression', '*_long_moves.png', 'long-moves')),
    card('Status, empty and zero-PP slots', one(a.after/'regression', '*_status_empty_zero_pp.png', 'special-slots')),
    card('Doubles target selection', one(a.after/'flows', '*_double_target.png', 'targets')),
    card('Lance partner battle', one(a.after/'regression', '*_partner_commands.png', 'partner'))])

movies=[]
for folder,pattern,name,title,duration,posterpattern in [
    ('capture','*_ball_[0-9][0-9][0-9].png','throw','R-button ball throw',.05,'*_ball_shortcut.png'),
    ('catching','*_capture_[0-9][0-9][0-9].png','capture','Successful capture',.05,'*_last_ball_ready.png'),
    ('regression','*_ability_[0-9][0-9][0-9].png','ability','Long ability popup',.05,'*_info_after_popup.png'),
    ('turns','*_damage_[0-9][0-9][0-9].png','damage','Damage and HP drain',.05,'*_damage_090.png'),
    ('turns','*_experience_[0-9][0-9][0-9].png','exp','EXP and earned level-up',.1,'*_earned_level_summary.png'),
    ('gimmicks','*_activation_1_[0-9][0-9][0-9].png','zmove','Z-Move activation',.1,'*_selected_1.png'),
    ('motion','*_menus_[0-9][0-9][0-9].png','menus','Move details and SwSh Bag return',.05,'*_menu_poster.png')]:
    motion=clip(a.after/folder,pattern,name,duration)
    # The level-up screen is deliberately captured several times while waiting.
    matches=sorted((a.after/folder).glob(posterpattern))
    if len(matches)>1:
        poster=one(a.after/folder,matches[0].name,name+'-poster')
    else:
        poster=one(a.after/folder,posterpattern,name+'-poster')
    movies.append('<figure><img loading="lazy" src="'+poster+'" data-poster="'+poster+'" data-motion="'+motion+'" alt="'+title+'"><figcaption><b>'+title+'</b><p><button onclick="toggleClip(this)">Play clip</button></p></figcaption></figure>')
section('4. Motion', movies, 'Lossless sampled emulator frames. These clips show presentation and transitions; they are not hardware frame-rate measurements.')
section('5. Existing flows', [
    card('Battle → SwSh Party',one(a.after/'shared','*_battle_party.png','party')),
    card('SwSh Summary',one(a.after/'shared','*_summary.png','summary')),
    card('Actual egg hatch',one(a.after/'shared','*_hatch_message.png','hatch')),
    card('Faint replacement',one(a.after/'turns','*_replacement_selected.png','replacement')),
    card('Safari counter',one(a.sweep,'ExpansionHealthboxes_*_safari_balls_29.png','safari')),
    card('Kanto Old Man',one(a.sweep,'CatchTutorial_*_kanto_old_man_line.png','old-man')),
    card('Hoenn Wally',one(a.sweep,'CatchTutorial_*_wally_wally_line.png','wally')),
    card('Bug-Catching Contest',one(a.after/'flows','*_contest_commands.png','contest'))])
section('6. Current environments and outfits', [
    card('Bright sand',one(a.after/'palettes','*_sand_moves.png','sand')),
    card('Dark cave',one(a.after/'palettes','*_cave_moves.png','cave')),
    card('Ice Path — current background',one(a.after/'palettes','*_ice_path_moves.png','ice-path')),
    card('Snowy Mt. Silver — current background',one(a.after/'palettes','*_mt_silver_snow_moves.png','snow'))])
section('All six outfits, both player sprites', [card(('Player 1' if i<6 else 'Player 2')+' / outfit '+str(i%6+1),one(a.after/'palettes',f'*_outfit_{i:02d}_intro_40.png',f'outfit-{i:02d}')) for i in range(12)])

page='<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Pokémon World · BW battle UI review</title><style>\n:root{color-scheme:dark;font:16px/1.5 system-ui;background:#10151f;color:#e9eff8}body{max-width:1060px;margin:auto;padding:28px 20px 70px}h1{font-size:clamp(28px,5vw,44px);line-height:1.1;margin:10px 0}h2{margin-top:45px;font-size:23px}p{color:#aebcd0}a{color:#8dc9ff}header{border-bottom:1px solid #35445a;padding-bottom:24px}.eyebrow{color:#9bdacc;text-transform:uppercase;letter-spacing:.15em;font-size:12px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,300px),1fr));gap:18px}figure{margin:0;background:#192230;border:1px solid #35445a;padding:12px;border-radius:12px}img{width:100%;max-width:480px;height:auto;aspect-ratio:3/2;object-fit:contain;image-rendering:pixelated;background:black;display:block;margin:auto}body.native img{width:240px;max-width:100%}figcaption{padding:12px 3px 0}figcaption p{margin:4px 0 0;font-size:14px}button{border:1px solid #7298bd;background:#253b53;color:white;padding:8px 14px;border-radius:6px;cursor:pointer}aside{border-left:3px solid #83c6b7;padding:2px 18px;margin:24px 0}.tools{display:flex;gap:18px;align-items:center;flex-wrap:wrap}.note{font-size:14px}\n</style><header><div class="eyebrow">Pokémon World / issue #336</div><h1>BW battle UI</h1><p>A 5–10 minute review of the implemented interface. Start with the three comparisons, then play the clips.</p><div class="tools"><button onclick="document.body.classList.toggle(\'native\')">Toggle native 240×160 size</button><a href="README.md">Implementation and limitations</a><a href="evidence/results.json">Automated results</a></div></header><aside><b>Final playtest</b><p>Use the prepared Route101 save. Try Fight → L details → B, open Bag and Pokémon/Summary, then use R to throw or hold R and press a direction to change balls.</p><p class="note">Cable Club is disabled in the current game; the direct link harness hits the same startup error on baseline and BW. Ice/snow captures show World\'s current map-selected backgrounds. New background art remains #327.</p></aside>' + ''.join(sections) + '<footer><p>Native PNGs are unchanged emulator output. Imported art and outlined fonts: Mudskip/mudskipper13; engine: RHH/pret. <a href="evidence/media-manifest.json">Capture provenance</a>.</p></footer><script>function toggleClip(button){const img=button.closest(\'figure\').querySelector(\'img\');const playing=button.textContent===\'Pause clip\';img.src=playing?img.dataset.poster:img.dataset.motion;button.textContent=playing?\'Play clip\':\'Pause clip\';}</script></html>'
(a.out/'index.html').write_text(page)
(a.out/'evidence/media-manifest.json').write_text(json.dumps(provenance,indent=2)+'\n')
print('Published',len(provenance),'review assets')
