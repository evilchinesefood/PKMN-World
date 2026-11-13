# Current game showcase

Twenty native 240 × 160 mGBA screenshots captured on 2026-09-29. Images are unretouched.
Files 01–14 cover the production title, World Transit, Kanto, Johto, Hoenn,
Battle Frontier and Battle Net. Files 15–20 show party, bag, summary, DexNav,
a wild battle and Options.

The main [README](../../../../README.md) shows a 12-image subset: it omits 03, 04, 07, 08,
10, 11, 12 and 14.

Overworld captures use the production debug warp menu and a synthetic party in
a disposable new game. Menu/battle fixtures seed items and Pokémon and invoke
the existing game screens; no renderer or graphics are replaced. The showcase
is not an end-to-end campaign playthrough. [manifest.json](manifest.json) records
ROM and fixture hashes, setup and per-image hashes.

The capture scripts are in this folder. To reproduce the same screens, use the toolchain and
patched mGBA from [the native verification guide](../../../../test/overworld/mgba/README.md).
A rebuilt ROM can change the hashes and idle positions that depend on RNG.

```sh
make modern -j8
S=graphics/branding/screenshots/showcase
test/overworld/mgba-run.sh $S/capture_world.lua --case-name ShowcaseWorld --out /tmp/pw-showcase/world
python3 test/overworld/visual-features/build_fixture.py --repo . --rom pokemonworld.gba --elf pokemonworld.elf --source $S/capture_fixture.c --out /tmp/pw-showcase/menus-fixture
python3 test/overworld/swsh-refresh/export_symbols.py pokemonworld.elf /tmp/pw-showcase/menus-fixture
python3 test/overworld/visual-features/run_fixture.py --repo . --fixture /tmp/pw-showcase/menus-fixture --suite $S/capture_menus.lua --out /tmp/pw-showcase/menus
python3 test/overworld/visual-features/build_fixture.py --repo . --rom pokemonworld.gba --elf pokemonworld.elf --source test/overworld/world-menu-theme/fixture.c --out /tmp/pw-showcase/battle-fixture
python3 test/overworld/swsh-refresh/export_symbols.py pokemonworld.elf /tmp/pw-showcase/battle-fixture
python3 test/overworld/visual-features/run_fixture.py --repo . --fixture /tmp/pw-showcase/battle-fixture --suite test/overworld/world-menu-theme/capture-battle.lua --out /tmp/pw-showcase/battle --env PW_BATTLE_MODE=0
python3 test/overworld/visual-features/build_fixture.py --repo . --rom pokemonworld.gba --elf pokemonworld.elf --out /tmp/pw-showcase/options-fixture
python3 test/overworld/visual-features/run_fixture.py --repo . --fixture /tmp/pw-showcase/options-fixture --suite test/overworld/world-menu-theme/capture-options.lua --out /tmp/pw-showcase/options
```

The six older screenshots one directory above remain as historical branding assets.
