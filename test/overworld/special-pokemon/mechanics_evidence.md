# Mechanics verification boundary

The 32 allocated flags occupy 0xDD0 through 0xDEF inside existing FLAGS_COUNT capacity. `python3 test/overworld/special-pokemon/mechanics_audit.py` compiles every FLAG_ macro and confirms no external alias or duplicate resolves to this range.

All 1573 existing explicitly numbered species retain their values against baseline 534c199cc2. New collection species occupy 1573 through 1582. Existing form entries retain their order, with collection forms appended. The legacy Original Cap record is unchanged.

SPECIES_EGG moves with the existing CUSTOM_END sentinel. Ordinary Egg records store their hatch species in PokemonSubstruct0.species and the independent isEgg bit. CreateEgg creates the hatch species first; GetBoxMonData synthesizes SPECIES_EGG for MON_DATA_SPECIES_OR_EGG, or for a bad Egg. Source inspection found no saved Egg record or save migration storing the sentinel as its real species. Union Room advertisement and storage-display uses are transient. This is source evidence, not an old-save runtime result.

The collection keeps normal ability pools, genders, base stats, types and ordinary level-up/teachable learnsets. Its themed move is an explicit additional reminder/teachable exception. Ordinary Pikachu already learns Surf in the baseline; Fly remains exclusive to Balloon Pikachu. Nonbreeding egg-group metadata rejects either parent position before Ditto handling. Null evolution/form-change metadata uses the engine's no-change defaults.

The new catalog passed the project's text preprocessor and ARM compiler syntax check. The parent also compiled special_pokemon.o, move_relearner.o, random_mon_generation.o and trade.o through Make. ValidateOwMonPlacements passed after extending its species-header discovery and retaining explicit OVERWORLD metadata for each collection species.

## Runtime checks

`mechanics_run.py --rom <rom> --elf <elf> --out <fresh-directory>` links the test-only fixture into verified-unused ROM padding, extracts the reminder callback from the exact ELF, and invokes five focused checks through the existing emulator runner. Expected command bitmasks are 1023, 1023, 1023, 63 and 1023.

The checks cover all ten actual source generation paths, repeat individuals and regional identity allocation, ordinary metadata, themed move uniqueness, nonshiny/no-item awards, breeding in both parent positions, every evolution mode, storage failure/retry, additive ownership reconciliation in party/PC/both daycares, repeat encounter generation, unchanged legacy cap, ordinary breeding/evolution, and actual reminder-list membership after forgetting.

The fixture source compiles with ARM -Wall -Werror. Runtime execution awaits a complete ROM with final artwork. These source/build checks do not establish battle, follower, quest, checklist or save/Continue acceptance.

## Requested 15% base-stat boost (2026-11-12)

The owner requested the seven retained collection variants have about 15% higher stats. Each of the six base stats is multiplied by 1.15 and rounded to the nearest integer (half up), only in the collection species definitions. Ordinary species and legacy Original Cap metadata are untouched. HP and other displayed battle stats continue to use the ordinary level/IV/EV/nature formulas; their displayed percentage gain is therefore not a flat 15% at every level.

Current generation configuration, columns HP / Attack / Defense / Sp. Attack / Sp. Defense / Speed:

| Collection variants | Base stats | Total | Gain |
|---|---|---:|---:|
| Classic Cap, Surfboard, Balloon Pikachu | 40 / 63 / 46 / 58 / 58 / 104 | 369 | 15.31% |
| Squad, Firefighter Squirtle | 51 / 55 / 75 / 58 / 74 / 49 | 362 | 15.29% |
| Flower Crown Eevee | 63 / 63 / 58 / 52 / 75 / 63 | 374 | 15.08% |
| Pirate Totodile | 58 / 75 / 74 / 51 / 55 / 49 | 362 | 15.29% |

The acquisition fixture now checks boosted species metadata against the ordinary species. A sixth runtime case creates level-50, neutral-nature, zero-IV/EV Pokémon and checks all six calculated stats for every variant. It also checks the four ordinary species and legacy Original Cap against their original baseline stat sets. Expected mechanics masks: `007F / 007F / 03FF / 003F / 007F / 007F`.

Worker checks: host validation 23/23 passed; `git diff --check` passed. Host log `/tmp/pkmn-386/boost-stats-host.log`. Parent owns the new production build and emulator run; earlier mechanics runtime reports predate this boost.
