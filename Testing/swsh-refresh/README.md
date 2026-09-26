# SwSh refresh — issue #328

Selective backport onto World's installed expansion revision. Review [the native before/after gallery](index.html). The test fixture enters production screens from a disposable, freshly generated game; it is never linked into the delivered ROM.

## Scope and provenance

Donor: [montmoguri/pokeemerald-expansion](https://github.com/montmoguri/pokeemerald-expansion). World's comparison baseline is `8f98876d0237b5e845707471b2f4e821bb61cc82`, including the approved #329/#332/#333 work. The prerequisite PR is #337.

| Component | Pinned donor commit | World adaptation |
| --- | --- | --- |
| Bag | `4d15e63ade9d835602e09dd26ea672098e13bf1e` | New art, BG money/price frames, prompts, HM and contest hearts; retain World's six-column party panel, item controls and configuration names. |
| PC palettes | `5ea873b96d7f6238fc3ea503b4685b14279eb91a` | Main/text/wallpaper banks 0/1/2, border 14, standard menu 15. Both wallpaper fade masks also target bank 2. |
| Summary lifecycle | `92f0196a4b23d26b2c1f881a5347fd5a914947ce` | Printer replacement/teardown, stop Conditions DMA, clear windows and delay effect BG reveal. Retain World shadow/transparency behavior. |
| Secondary message frames | `0654d95b060a758647f560d555229ddd8bf48e9b` | Named, nonoverlapping tile allocations derived from World's actual windows. |
| Party/PC callback | `ad55dc9969e78d4fca76332738a2d56838d58f4c` | Consume the return callback before recreating the party menu. |

Credits and component attribution are in [CREDITS.md](../../CREDITS.md), including the correction identifying ShantyTown as comfy_anim's author and Archie as its introducer. The pinned features are documented by the donor for reuse with attribution; this is not a claim of a blanket repository license.

No engine upgrade, configuration rename, extra pockets, status/level fade, compact digits or HnS Fuchsia art is included. Mudskipper's BW battle UI remains #336; this branch tests transitions through the currently installed battle UI, not the future port.

## Graphics and memory ownership

`verify_assets.py` compares ten unchanged donor Bag files and the PC sheet byte for byte. It also reproduces these adaptations without writing files:

- Party frame: keep columns 0, 1, 2, 3, 6 and 7 of the donor's eight-column map. Preserve World's icon, HP and status positions.
- Partner cue: extract World's original ten cue tiles and remap old black/white indices 4/9 to 5/4. This preserves the existing control hint instead of interpreting old tile IDs in the new sheet.
- Wallpaper maps: retain every low 12-bit tile/flip value and change only palette 1 to 2. All 20 results also match the pinned donor. IDs, artwork, box count and save values are unchanged.

Bag artwork and its ten extra partner-cue tiles use charblock 2 (`0x8000..0xA13F`), clear of text and screen blocks 28–31 (`0xE000..0xFFFF`). The appeal/jam window uses tiles 683–698, after the existing party HP window at 619–682. Money-label sprites own their palette; existing quantity sprites and World item-use flows remain in place. Pocket arrows leave the information prompt clear, including the full partner-party layout. `item_icon.h` is included independently of direct item-use configuration because the registered-item wheel also calls it.

| Screen | First frame tile | Reserved tiles | Placement |
| --- | ---: | ---: | --- |
| Shop | `0x222` | 25 | After Yes/No window `0x20E + 5×4` |
| Pyramid Bag | `0x22C` | 25 | After largest action window `472 + 14×6` |
| Pokéblock Case | `0x21E` | 25 | After toss Yes/No window `0x20A + 5×4` |
| Berry Blender | `0x186` | 25 | After results window `0x60 + 21×14` |

The classic frame's 14 tiles fit in the same allocations. Loading and drawing use the same constants.

## Reproducing the emulator evidence

Build with the repository's toolchain and Lua-enabled mGBA described in [Testing/mgba](../mgba/README.md). Set `TOOLCHAIN=/opt/devkitpro/devkitARM` if it is not already configured. Use absolute ROM/ELF paths.

```sh
make modern TOOLCHAIN=/opt/devkitpro/devkitARM -j8
python3 Testing/swsh-refresh/build_fixture.py --repo . \
  --rom "$PWD/pokemonworld.gba" --elf "$PWD/pokemonworld.elf" \
  --source-ref "$(git rev-parse HEAD)" --out /tmp/swsh-fixture
python3 Testing/visual-features/run_fixture.py --repo . \
  --fixture /tmp/swsh-fixture --suite Testing/swsh-refresh/capture.lua --out /tmp/swsh-capture
```

Run `regression.lua`, `items.lua`, `pc_transfer.lua`, `transitions.lua` the same way. Run `battle.lua` three times with `PW_BATTLE_MODE=0`, `1`, `2` for singles, doubles and full partner teams. `verify_assets.py --donor /path/to/donor-checkout` requires the five pinned donor objects; it does not fetch or import anything.

The helper resolves duplicate local symbols by the owning object's linked address range in the matching `.map`, not by `nm` order. It checks only on-screen window allocations; the PC's off-screen information panels intentionally reuse tiles. GBA scroll registers are write-only, so visibility uses the game's GPU register buffer. Palette comparisons omit transparent backdrop entry 0, which the renderer forces black. All other main/text colors are checked, including throughout the wallpaper animation.

The fixture sets the existing L/R button-mode option to exercise Bag partner-page switching. It seeds 999 Super Potions, six species, a poisoned mon, an almost-fainted lead, depleted PP, contest stats and occupied PC boxes. Fixtures, screenshots, ROM hashes and command results are recorded with the evidence. Existing saves are covered separately by the tracked migration suites; no personal save is touched.

## Validation and review handoff

The final evidence and delivery manifest accompany the gallery. Development and release configurations are compiled; only the tested development ROM is delivered, following [RELEASING.md](../../RELEASING.md). Additional compile probes use classic messages and disable contest/berry/direct-use options and Summary contest/blend/shadow options in an isolated copy.

The focused suites cover all pockets and empty pockets, 999 quantities, sorting across a seeded gap, healing, PP recovery, Give, TM replacement through Summary, evolution/reentry, selling, PC/party callback reuse, all wallpaper IDs, real wallpaper transitions, PC Summary/markings, deposit/withdraw, actual item swapping, repeated Summary page/mon changes and heap stability, egg/status cases, all four secondary-frame prompts, and synthetic save/reload. The repository sweep covers Hub Pass, EV/IV prompts, tutorial battles, region travel and save migrations.

The owner review should take 5–10 minutes: compare Bag/TM/berry/sell screens, inspect PC information and wallpaper transitions, watch Conditions entry/exit, then use normal Bag/PC/Summary controls in the prepared build. This is final appearance judgment; engineering validation is the agent's responsibility.
