# BW battle UI — issue #336

The [visual review](index.html) pairs native before/after captures and short motion clips. The owner selected Mudskipper's angular command/move panels, outlined healthboxes, party bars, ability popups and L/R/gimmick controls. This port retains World's engine, save layout, regional tutorials, SwSh Bag/Party/Summary and existing mechanic eligibility.

Baseline: `12934378f9ca2cb11a95cafe94669f90f9a0ff23`. Donor: `mudskipper13/pokeemerald` at `b798929811ec7d070616c7ef47e46cfc6a7f1501`, feature-only parent `68a5890c8548bc04e92b9cdf188aedc11345fc87`. The donor inventory is 65 files, including 37 graphics. `verify_assets.py` compares those graphics with the pinned commit; JASC palette line endings follow World's checkout rules. Mudskip, RHH and pret are credited in [CREDITS.md](../../CREDITS.md). No explicit standalone BW license was found; the author's public feature listing supplies provenance, not an invented blanket license.

## Integration decisions

- Full move names use a measured name/icon/PP budget with four pixels of separation. The bundled narrow font fits normal cases; exceptionally long names use a second row while retaining the complete name, PP and effectiveness. Empty slots clear stale text. A fixture checks every move name against the fallback width.
- Type/effectiveness uses World's `DamageContext`, target helpers and current ability/item/weather/terrain logic. Preview calls restore helper-written state and ignore stale previous-action Mold Breaker state. Thirteen cases compare the entire battle structure and RNG before/after preview; actual doubles target cycling and cancellation are exercised separately.
- Fonts 0–13 keep their identities. Outlined, narrow outlined and element fonts occupy 14–16. `fontId` uses existing padding; `TextPrinter` remains 48 bytes, `nextPrinter` remains at offset 44 and its template remains 28 bytes. `Subsprite` remains four bytes with signed-byte coordinates; a local Z-cursor coordinate adjustment avoids widening the shared structure. Menu digits retain their existing font bindings.
- Nickname redraw resolves Illusion for name/gender while retaining the actual level, and erases the full 56-pixel fitted name area. Silph Scope unveiling dispatches through BW nickname/status rendering. Both player and opponent VRAM are compared with clean renders after long-name disguise changes.
- Allocation failure is handled before indexing sprites. Cursor failure uses the module's `SPRITE_NONE=255`, while the allocator returns `MAX_SPRITES=64`; the two values are deliberately distinguished. Ability popups release partial allocations, track their own tasks/printers, preserve unrelated mosaic bits and restore prior object mosaic on normal or early exit.
- Recorded playback had a baseline failure: `PlayRecordedBattle` allocates a party backup before battle initialization, which then reset the heap and erased it. Playback initialization now preserves that allocation. The same reproduction fails on baseline and returns correctly after the fix, including a subsequent ordinary battle.

## Graphics and resource ownership

| Allocation | Owner and lifetime |
| --- | --- |
| BG palettes 0–1, 10–13 | BW textbox, command/move cells; environment palettes stay in 2–4. Runtime comparisons cover grass, sand, cave, Ice Path and snowy Mt. Silver. |
| BG0 charblock 0, screenblocks 24–25 | Text/command/move windows. Normal/Z layouts are mutually exclusive. Move window bases are `0x200`, `0x2AC`, `0x2D6`, `0x300`; description starts at `0x32A`. Regional first-battle/Oak and level-summary windows retain separate entries. |
| BG1/2 charblock 1, screenblocks 28–31 | Existing animation/entry surfaces; sprite-to-BG clearing uses tile zero for BW outside contests. |
| BG3 charblock 2, screenblocks 26–27 | Existing battlefield selection/art; this port does not recolor environments. |
| Cursor OBJ tag `0x9999` | BW cursor only; create/close/menu-return teardown. |
| Shortcut OBJ palette `0xE723` | L/R trigger sprites share this private palette until both tile tags are released. They do not own the ability-popup palette. |
| Popup palette `0xD720`, per-battler tile tags | Shared palette remains until all popups release it. Each popup owns two linked sprites, its task and text printers. |
| Healthboxes, party bars, gimmick indicators | Existing named tags in `battle_interface.h`; World party-summary reference counting and named gimmick mapping are retained. Healthbox and indicator bounds are checked before indexing. |

`BattleUI_ResetGraphics` releases BW resources on screen closure and final battle teardown, including forced exits. Thirty repeated single/double battle → Bag → info → field cycles assert stable heap, sprites, tasks, active text owners and allocated OBJ tiles. Separate fixtures exhaust sprites, tasks and palettes and verify recovery. Two simultaneous popups and early cancellation verify mosaic/palette ownership.

## Reproduce

Use the toolchain and Lua-enabled mGBA in [Testing/mgba](../mgba/README.md). These fixtures only patch disposable ROM copies in verified unused padding; no boot hook, seeded party or test command enters the shipped ROM.

```sh
make modern TOOLCHAIN=/opt/devkitpro/devkitARM -j8
python3 Testing/bw-battle-ui/build_fixture.py --repo . \
  --rom "$PWD/pokemonworld.gba" --elf "$PWD/pokemonworld.elf" \
  --source-ref "$(git rev-parse HEAD)" --out /tmp/bw-fixture
python3 Testing/bw-battle-ui/run_all.py --repo . \
  --fixture /tmp/bw-fixture --out /tmp/bw-checks
Testing/run-all.sh
Testing/mgba-run.sh Testing/lua/LanceMultiBattle.lua
make check TOOLCHAIN=/opt/devkitpro/devkitARM -j8
make validate
make release TOOLCHAIN=/opt/devkitpro/devkitARM -j8
python3 Testing/bw-battle-ui/verify_assets.py --donor /path/to/pinned/donor
```

`run_all.py` removes old sentinels, requires matching fixture-ROM hashes and reports every suite. The symbol exporter resolves duplicate local controller names by their owning object's address range in the exact ELF/map. Long rendering hooks wait for completion before reading results. The fixture records ROM/ELF/map/configuration/source hashes. It supplies obedient test Pokémon, fixed RTC, real battle/capture calculations and actual hatch/trade scenes. Trainer cleanup in the repeated resource loop is forced at a command boundary; `turns.lua` separately earns a real victory/level, faints and replaces a mon, and loses through whiteout.

## Validation limits

World currently compiles Cable Club rooms out (`LINK_CABLE_CLUB=FALSE`). A test-only two-core mGBA SIO harness attempted direct link battle startup. Both baseline and BW fail the same initial protocol checksum exchange, before battle presentation. No successful live link session or physical GBA timing profile is claimed. The port does not enable Cable Club or change link/save formats.

Snow/ice metadata environment IDs currently have no graphics assigned. Forcing those IDs reproduces the existing decompression failure; they are not used as pretend visual coverage. Captures instead enter actual Ice Path and snowy Mt. Silver maps and exercise the backgrounds World currently selects. New snow/ice art and palette work remains #327. The cancelled regional palette proposal, HnS Fuchsia tiles and compact menu digits remain excluded.

Release-mode compilation is checked. The delivered ROM is the tested development build, following [RELEASING.md](../../RELEASING.md), with a generated synthetic save. No personal save is modified and no ROM is uploaded to GitHub.

## Final owner review

Spend 5–10 minutes on the gallery and ordinary play: compare the command/move screens; watch the ball, popup and HP/EXP clips; open Fight → L details → B, Bag and Pokémon/Summary; try R to throw or R+D-pad to cycle. The prepared save starts on Route101 with six Pokémon and balls. Technical fixtures, debug setup and regression checks are already handled by the agent.
