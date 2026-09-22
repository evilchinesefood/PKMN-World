#!/usr/bin/env python3
"""Verify the Rocket HQ scene names both opponents and its partner."""
from pathlib import Path
import re
root = Path(__file__).resolve().parent.parent
script = (root/'data/maps/MahoganyHideout_B2F/scripts.inc').read_text()
scene = script.split('MahoganyHideout_B2F_EventScript_DoLanceMultiBattle::')[1].split('MahoganyHideout_B2F_EventScript_DefeatedAriana::')[0]
assert re.search(r'multi_2_vs_2\s+TRAINER_ARIANA_1,\s*MahoganyHideout_B2F_Text_ArianaLoss,\s*TRAINER_GRUNT_23,\s*MahoganyHideout_B2F_Text_GruntLoss,\s*PARTNER_LANCE',scene), 'scene must initialize Ariana, Grunt and Lance'
assert 'SPECIAL_BATTLE_LANCE' not in scene
assert 'ReducePlayerPartyToSelectedMons' not in scene, 'multi macro owns party reduction/restoration'
partners=(root/'src/data/battle_partners.party').read_text()
lance=partners.split('=== PARTNER_LANCE ===')[1]
assert 'TRAINER_PIC_CHAMPION_LANCE' in lance and 'Dragonite' in lance
print('PASS: Rocket HQ uses explicit trainers and the standard multi-battle party lifecycle')
