# Source, capture, and recovery evidence

Tested 2026-11-12 against immutable production input `/tmp/pkmn-386/build-2/pokemonworld.gba`, SHA-256 `0aa34607861992bb8494ce36b7c28b725fe67ec55558c7721b239920277e6197`.

## Scope and method

`capture_run.py` injects `sources_fixture.c` into a copied ROM and runs fresh isolated native mGBA sessions. Setup supplies a party, balls, and adjacent-map warps. Source interactions, task progress, battle input, catch outcomes, save, reset, and Continue use normal game code. No capture outcome or collected flag is injected after setup. These are headless scenario tests, not a complete natural campaign or human playtest.

The battle setup creates a level-100 Jolteon with Seismic Toss and met level 1 for obedient KO/catch testing, then a level-1 Magikarp with 1 HP for loss testing. Preparing a new party deposits the previous party in PC storage. Master Balls ensure deterministic successful catches.

## Verified

- Source suite: 41 assertions. All 22 source placements interact; six gift variants are awarded through their NPC/task scripts. The flower gift uses PC overflow with a full party.
- Squad, kiln, flower, and ordered trail task progression works. A premature third trail clue does not unlock Explorer.
- Ordinary save/reset/Continue during water delivery retains task progress before the kiln reward.
- Declining all four encounters leaves their collection flags unset; repeat gift conversations preserve marks.
- Capture suite: 36 assertions. Surfboard run, target KO, and player defeat return field control and preserve its unlocked, uncollected source.
- Actual Surfboard, Pirate, Explorer, and Swim Ring Master Ball catches set their corresponding collection flags. All four are found in party/PC ownership afterward.
- Ordinary save/reset/Continue retains four capture marks and owned Pokémon. A cross-region map revisit permits a fifth actual catch.

Not covered here: a ball breaking out, full-storage catch refusal, every recovery outcome on each of the four sources, natural region travel, or human visual acceptance. Separate host script checks exercise storage-refusal branches.

## Fixture corrections during testing

Arrival narration is dismissed using normal B input before interactions. Continue accepts the saved map group rather than requiring the initial hub. Surfboard is approached from the south to avoid an unrelated existing trainer sightline. Seeded Jolteon met level 1 avoids intended obedience refusal. None required a production-code change.

Final run outputs: `/tmp/pkmn-386/capture-final/sources/` and `/tmp/pkmn-386/capture-final/capture/`; each includes result JSON, verdict log, and screenshots. Run manifests record input, patched ROM, symbols, and fixture-source hashes.
