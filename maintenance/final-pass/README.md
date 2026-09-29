# Pokémon World final maintenance pass — 2026-09-29

Baseline: `e38ee10ffb01c45d5e125dc7cfc5601a467c7c29` on the repository's existing
default branch, **master** (`origin/HEAD -> origin/master`). There was no `main`
branch. This pass uses the existing default branch, with no unsolicited branch
rename. Your pre-existing README engine-version correction is preserved; your
untracked UI review is moved to `test/overworld/ui-review` and stays uncommitted.

## Decisions and status

- [Quest log decision](quest-log-decision.md): recommend a lightweight reminder;
  zero formal authored entries, at least 53 major story/badge objectives under
  an explicit grouping rule. Nothing implemented.
- [Zone audit](zone-status.md): 100% of registered map structures checked in
  each zone, zero remaining structural errors. Feature-completion percentages
  remain unverified; no unsupported feature-complete claim added.
- [Thirty-commit adversarial review](review.md): five review defects fixed,
  plus a sealed-map warp and a fixture-builder encoding defect.

## Cleanup and restoration

`Testing/` is consolidated under `test/overworld/`, alongside the inherited C
battle suite in `test/`. Current scripts, Make/CI/hooks, paths and root discovery
were adjusted. Test-only C fixture entry points are explicitly excluded from the
inherited test ROM. Historical `evidence/` and `review/` payloads remain byte-for-byte
unchanged apart from directory moves; their old path strings are provenance, not
current setup instructions. The local pre-push hook was relinked to the new path.

Branding now lives in `graphics/branding/`. FRLG intro/credits/title resources are
nested under `graphics/intro/frlg/`, `graphics/credits/frlg/` and
`graphics/title_screen/frlg/`. Berry-fix graphics live under `graphics/berries/fix/`;
its C header name stays `src/data/graphics/berry_fix.h`. Updated build/source
references were verified by a fresh object/asset build. Semantically different
sprite/palette variants and community UI sets are retained rather than treating
similar names as duplicates.

[Moves](moves.json) records the folder mappings.
[Removed files](removed-files.json) records every deletion: **69 graphics**
(50,371 bytes) and **four map/script files** from three unregistered unused houses.
For graphics, basename/token searches covered code, build rules, tests, tools and
documentation. Parameterized species/font/type/weather assets were retained.
For maps, registrations, destinations, script includes and symbol references
were searched; only self-references remained. `Route6_UnusedHouse_Frlg` stays
because its script is included. The manifest records size, original SHA-256,
reference-check rationale and the restore revision for each file.

Restore an individual removed file from the baseline (create its parent first):

```sh
git show e38ee10ffb01c45d5e125dc7cfc5601a467c7c29:path/from/removed-files.json > path/from/removed-files.json
```

If restoring pre-cleanup graphics referenced by an old path, restore their old
location or apply the mappings in `moves.json` consistently. Git history retains
all originals. Personal saves, ROMs and historical review archives were not removed.
The scratch build directory created by this pass was removed after verification;
the normal playable build remains in place.

An early relocation also changed the berry-fix **C include name**, causing a
compile failure. That attempted include rename was backed out immediately; the
header's graphic paths alone were updated. A moved WorldTitle test briefly used
the old relative path; corrected, it passes 37/37. Both are corrected maintenance
attempts, not unresolved build failures or committed regressions.

## Verification

- `make modern -j8`: successful before and after changes.
- `make modern BUILD_DIR=build-final-clean -j8`: successful fresh game objects
  and assets, exposing/fixing stale incremental palette dependencies. The normal
  incremental build then produces the identical ROM.
- `make validate`: all host/content gates pass, including the new zone validator.
- `make check -j8`: exit 0; 5,084 passed, eight expected-failing, 14 upstream
  known-failing and 594 TODO tests, 5,700 total. No unexpected failure. These
  skipped categories are not described as passing tests.
- Fresh complete emulator sweep: **51/51**, including 50 mandatory suites and
  the optional owner-save suite, stamped
  `FE895EAEE1A58E10DDB5687BF6B46DA1`.
- Optional menu layouts: **8/8**. Palette Make dependency regression: **4/4**.
  Hub/lighting publisher negative checks reject malformed, partial, duplicate,
  zero-assertion and failed-exit evidence.
- Actual screenshot runs: world **28/28**, menus **7/7**, battle **8/8**, Options
  **1/1**; boot and title are also covered by the fresh sweep.

[Verification summaries and logs](verification/) contain the fresh sweep,
ROM-stamped sentinels and screenshot runners. Memory use: EWRAM 235,064/262,144;
IWRAM 28,216/32,768; ROM payload 22,939,200/33,554,432 bytes. Existing unused-function
and RWX-linker warnings remain; “build succeeds” does not mean warning-free.

Host scaninc recompilation encountered a local Xcode/CommandLineTools SDK mismatch.
Using the installed Xcode SDK resolved it:

```sh
make -C tools/scaninc CXXFLAGS='-Wall -Werror -std=c++11 -O2 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk'
```

This is a local toolchain workaround; the game code did not need a rollback.

## Screenshots

[Twenty native screenshots](../../graphics/branding/screenshots/showcase/README.md)
cover title, both hub floors, three Kanto towns, three Johto towns, four Hoenn
towns, Battle Frontier, party, bag, summary, DexNav, battle and Options. All appear
in the main README. Images are unretouched emulator output. Debug warps, synthetic
teams/items and test-only fixture hooks set up scenes; no personal save is used
and these captures are not campaign-completion evidence. The gallery manifest
records ROM/fixture/per-image hashes.

Reproduce the same *screens*, using the toolchain and patched mGBA documented in
`test/overworld/mgba/README.md`. Rebuilt ROM versions may change their hashes and
RNG-dependent idle positions:

```sh
make modern -j8
PW_OUT=/tmp/pw-showcase/world test/overworld/mgba-run.sh maintenance/final-pass/capture_world.lua
python3 test/overworld/visual-features/build_fixture.py --repo . --rom pokemonworld.gba --elf pokemonworld.elf --source maintenance/final-pass/capture_fixture.c --out /tmp/pw-showcase/menus-fixture
python3 test/overworld/swsh-refresh/export_symbols.py pokemonworld.elf /tmp/pw-showcase/menus-fixture
python3 test/overworld/visual-features/run_fixture.py --repo . --fixture /tmp/pw-showcase/menus-fixture --suite maintenance/final-pass/capture_menus.lua --out /tmp/pw-showcase/menus
python3 test/overworld/visual-features/build_fixture.py --repo . --rom pokemonworld.gba --elf pokemonworld.elf --source test/overworld/world-menu-theme/fixture.c --out /tmp/pw-showcase/battle-fixture
python3 test/overworld/swsh-refresh/export_symbols.py pokemonworld.elf /tmp/pw-showcase/battle-fixture
PW_BATTLE_MODE=0 python3 test/overworld/visual-features/run_fixture.py --repo . --fixture /tmp/pw-showcase/battle-fixture --suite test/overworld/world-menu-theme/capture-battle.lua --out /tmp/pw-showcase/battle
python3 test/overworld/visual-features/build_fixture.py --repo . --rom pokemonworld.gba --elf pokemonworld.elf --out /tmp/pw-showcase/options-fixture
python3 test/overworld/visual-features/run_fixture.py --repo . --fixture /tmp/pw-showcase/options-fixture --suite test/overworld/world-menu-theme/capture-options.lua --out /tmp/pw-showcase/options
```

The separate battle fixture intentionally has an injured lead for its healing
checks; the showcase menu fixture displays a healthy party. Hook code lives in
scratch ROM padding and is never linked into the production game.

## Features documentation

README/FEATURES correct engine 1.16.4 dev, save v10 (v7–v9 migration), Johto
252/total 1,190 registered maps and 50/51 overworld suites. Unsupported distinct
trainer/static C-file counts are removed. Added current World title/panels,
selected window frames, BW battle UI and move details, regional/time battle
presentation, Viridian landscaping/frontages, 49-town warm windows, hub staff
art and refined live outfit colorways. Disabled quest/link facilities remain
explicitly off; obsolete Center 2Fs are described as sealed rather than deleted.
