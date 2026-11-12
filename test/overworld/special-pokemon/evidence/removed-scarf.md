# Seven-variant build scope

The owner removed Buddy Scarf Eevee after the earlier Treecko/Mudkip removal. Removed its catalog row, species declaration and data, Eevee Forms entry, acquisition NPC in Ecruteak, dialogue/scripts, and two exclusive flags. Pirate keeps species ID 1580. The removed 1579 slot is unused; no retained species IDs moved. The ephemeral catalog indices compact to 0..6, with Pirate at 6. Retained flags keep their numeric values; 22 remain.

Checklist totals already derive from `SPECIAL_POKEMON_COUNT`; the fixture expects seven details and two icons on the second page. The background-scroll regression remains intact. Sources now include 14 NPC placements, five gift variants, two catch variants and three tasks. The fixture repeats a real Classic Cap claim to fill the party before the flower reward, retaining the PC-overflow test.

Updated fixture expectations (not fresh runtime results): mechanics `007F/007F/03FF/003F/007F`; capture ownership mask `0042`; sources 31 assertions; capture 23; visual 127 (seven male and four female samples, one water mount); UI 1326. Female fixture offset is seven. Capture map revisit uses the remaining Goldenrod balloon seller instead of the removed Ecruteak trainer.

`python3 test/validate-host.py` passed 23/23 in 7.7 seconds; log `/tmp/pkmn-386/removed-scarf-host.log`. `git diff --check` passed. No Make or fresh emulator run was performed by this worker. Parent task owns the current art/build/runtime pass. No merge before owner approval.
