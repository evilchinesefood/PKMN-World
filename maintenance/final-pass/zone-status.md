# Verified zone status

**Feature-complete percentage: not established for any zone.** No arbitrary
percentage is substituted for a missing completion checklist. The source audit
covers every registered map; it does not prove every story state or post-game
route can be completed in a continuous playthrough.

| Zone | Registered maps checked | Structural audit coverage | Feature completion | What remains unverified |
|---|---:|---:|---|---|
| Kanto | 418 / 418 | 100% | Unverified | Continuous opening-to-Champion progression; full Sevii Ruby/Sapphire story and every legendary/event-ticket branch |
| Johto | 252 / 252 | 100% | Unverified | Continuous opening-to-Lance/Red progression; every Ruins of Alph, contest, GS Ball and legendary outcome |
| Hoenn | 518 / 518 | 100% | Unverified | Continuous Emerald story; all legendary gates and complete progression through each Frontier facility |
| World hub | 2 / 2 | 100% | Unverified | Every reward threshold, full-bag/PC/mail state and all championship permutations across long-running campaigns |

These remaining items are **verification gaps**, not demonstrated missing game
content. No reachable story stub or absent campaign component was established
by this pass. Therefore the README does not claim feature complete or label a
zone's development 100%. A real completion percentage requires an agreed list of
acceptance cases with each case executed and recorded. Calling an unexecuted
case a missing feature, or assigning it an invented development percentage,
would be equally misleading.

## Checks and content tracing

`test/overworld/ValidateZoneStructure.py` checks registered map groups against
layouts, blockdata sizes, border presence, local/shared script entry points,
warp destination maps/index bounds, map connections and encounter references.
`make validate` also runs the existing script-pointer, object-event, metatile,
palette, species, gifts and regional map checks. Their established advisory
baselines remain distinct from errors. The [JSON census](zone-census.json)
includes the dynamic warp list and all counts.

The 1,190 registered maps contain 6,605 object events, 3,395 warp events and
484 encounter headers. All 405 land headers have hidden encounter tables.
Sixty-five dynamic destinations plus 127/255 special warp conventions need
runtime handling; the validator explicitly excludes these from static numeric
bounds checking. Sealed link-era rooms, prototypes and generated facilities are
included in the map census; the numbers do not count 1,190 unique story quests.

- **Kanto:** FireRed scripts, eight badge gates, real league rosters and champion
  flag are wired. Celio's gem exchanges and Lostelle scripts exist, as do the
  legendary dungeons and event-island branches. `src/region_switch.c` reads
  `FLAG_KANTO_CHAMPION` independently of the other campaigns.
- **Johto:** eight gyms, Lance/Johto Hall of Fame, Red, GS Ball/Celebi, Ruins of
  Alph and contest scripts exist. `JohtoPokemonLeague_HallOfFame/scripts.inc`
  sets `FLAG_JOHTO_CHAMPION`. Dedicated emulator checks exercise Slowpoke Well,
  Rocket HQ multi battle, Whirlpool/Lugia access, Tin Tower, Tohjo Celebi,
  regional healing/Fly and the S.S. Aqua crossing.
- **Hoenn:** native Emerald map/script progression and Hall of Fame remain;
  `data/scripts/hall_of_fame.inc` sets `FLAG_HOENN_CHAMPION`. Frontier scripts,
  event-island branches and HARD rematches are present. The shared championship
  registrar checks all three champion flags before enabling the Dome bracket.
- **World hub:** departure gates, party boxing/mail handling, nurse, shared PC,
  badge board, rewards, ticket givers and gated Battle Net floor are implemented.
  Fresh tests exercise intro/tour, Hub Pass/re-entry, stairs gate and terminals.

A stub search found only disabled quest demonstrations, documented unused
helpers, deliberate no-op return branches and legacy text annotations. An old
region-switch TODO incorrectly described respawn work already implemented by
`SetRegionArrivalRespawn`; the comment is now accurate. That is not an unfinished
arrival system.

## Defect repaired

`EverGrandeCity_PokemonLeague_2F/map.json` targeted destination warp 4 in a lobby
with only four warps (valid IDs 0–3), after the Center 2Fs were sealed. Its return
now uses warp 0. The structural check failed on the old source and passes on the
fix. The room remains sealed in normal play; this repairs legacy/debug entry
without reopening removed link facilities.

## Retained legacy diagnostics

The existing all-layout audit also reports **1,611 out-of-bounds placements in
five unreferenced layouts**: four Ruby/Sapphire Safari Zone remnants (74, 13,
10 and 2 placements) and `LAYOUT_UNUSED_OUTDOOR_AREA` (1,512, with a NULL
secondary tileset). No registered `map.json` uses these layouts. They remain
explicitly allowlisted legacy data, not repaired playable maps. Removing entries
from the ordered layout table would renumber layout IDs used by saved map state;
this conservative pass does not risk that save compatibility change. They are
not evidence of a complete/clean legacy asset archive.

The 325 pinned blank metatile placements in 30 layouts are mostly dead space,
unused single-tile rooms and documented border/room emptiness. The map-event
scanner retains one Whirlpool sprite-name outlier (eight Whirlpool vs 32 Archer
tokens in the imported ID naming) and nine temporary cutscene choke-point
placements. The latter stage actors during locked scenes, which subsequently
move/remove them; the static scanner does not model the sequence. None grew in
this pass. These diagnostics are disclosed separately from the zero-error
registered-map structure check. Full reports are in
`verification/map-advisories.log` and `verification/metatile-advisories.log`.
