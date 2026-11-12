# Story destination map evidence

The destination captures below are unretouched 240 × 160 images from the
production viewer. The disposable fixture adds test entry code to unused ROM
padding. It also emits a matching test ELF, so the native runner reconstructs
and checks the fixture ROM before execution. The shipping ROM and ELF remain
unchanged. No ROM, ELF, or save is committed.

The final destination suite passed **1223/1223 assertions**. The
[complete log](destination-capture.log) and [source manifest](destination-manifest.json)
record the run and inputs. The shipping ROM SHA-256 is
`180ffedab7f8f1f499cdbd3d6559b99acee7445ce30c6cc9f44d98d2acc78e2b`.
The disposable fixture ROM SHA-256 is
`5504f5c0288757be088e3a44070f5b6df48a23d3347d5dc77417b7703d8ba0d0`.

The suite checks the following behavior.

- All 164 compiled objectives open in the production viewer. Every one of the
  156 pins occupies its authored section in the actual compiled map layout.
  All eight exemptions show an explanation with no marker. A null objective
  exercises the unknown destination fallback.
- All six map layouts render. Cross-region views omit the player icon, and
  matching physical locations show it. Both hub floors omit the icon after
  prior regional travel. The map and location pane hide and restore both
  cursor and player sprites after animation frames.
- Real Story entry covers all three main detail pages and both optional pages.
  The resolver refreshes a changed next action when the player opens the map.
  B restores the exact region, page, and detail selection from both map and
  location panes. Six extra repeated cycles restore the heap and active tasks.
  All sprite tile and palette allocations are zero after return. The first child releases eight stale field
  palette tags, and subsequent cycles retain zero allocations.
- A toggles location details. R, L, directions, Start, and Select cannot move
  the pin or enter travel. Before/after comparisons cover progression flags
  and variables, inventory, party, active campaign, location, warp destinations,
  respawn data, map header, regional teams, and regional Center records.
- All 820 objective text fields and the new controls fit the production font.
  The classic Start caller still opens Story. Ordinary Town Map and Pokedex
  area screens open and close after destination-view teardown.

The parent verification also passed the canonical Story suite, 31/31, and
Johto Fly/Teleport suite, 31/31, on this shipping ROM. Host validation passed
20/20 groups, including 1525 Story assertions and all 164 objective IDs.
These are targeted, debug-assisted checks, not continuous campaign playthroughs.

## Native views

| View | Capture |
| --- | --- |
| Hoenn | [Littleroot Town](destination-hoenn.png) |
| Kanto | [Pallet Town](destination-kanto.png) |
| Johto | [New Bark Town](destination-johto.png) |
| Sevii 1-3 | [Bond Bridge](destination-sevii-123.png) |
| Sevii 4-5 | [Five Isle Meadow](destination-sevii-45.png) |
| Sevii 6-7 | [Ruin Valley](destination-sevii-67.png) |
| Optional objective context | [Mt. Ember details](destination-optional-details.png) |
| No regional map location | [World Transit explanation](destination-hub-exemption.png) |
| Unknown destination | [Fallback explanation](destination-unknown.png) |
| Subsequent ordinary map consumer | [Pokedex area](destination-pokedex-return.png) |

## Reproduce the destination checks

Build the shipping ROM first, then create the disposable fixture.

```sh
python3 test/overworld/story-progress/build_fixture.py --out /tmp/pw-story
MGBA_HEADLESS=/path/to/pinned/mgba-headless \
  test/overworld/mgba-run.sh test/overworld/story-progress/capture.lua \
  /tmp/pw-story/VerifyFeatures.gba --case-name StoryProgress \
  --out /tmp/pw-story-capture --env PW_FEATURE_LIB=/tmp/pw-story/lua
```

Use the [pinned emulator setup](../../mgba/README.md) to obtain the executable.
The runner accepts the fixture library through `--env`; it intentionally removes
inherited `PW_` variables. The fixture manifests identify the exact production
sources, ROM, ELF, fixture source, and Lua suite.

---

## Original Story screen evidence

Native, unretouched 240 × 160 mGBA captures of the production renderer. The
isolated fixture lives in unused ROM padding and is excluded from shipping.
No ROM, ELF or personal save is included here.

The source base is merged PR #354 (`2deb1f92bb31ea89f071e281968f0c842cb023d3`).
The capture manifest records the input ROM/ELF, fixture source/output and each
production source hash, including new files not visible to a tracked diff.
The shipping ROM MD5 is `7C309CFABD61E42099FDEC246C23AED7`; its SHA-256 is
`343960c1b8e4fe8f3bd27d68b3b2d3b4cdc037f6a1dbf4a1d6efe151c29099b0`.

- Host resolver: 627 assertions; all 164 authored objective IDs exercised.
- Production Start menu: 31/31 checks (travel through all regions/hub, active
  defaults, regional isolation, heap restoration, real save/reboot/Continue).
- Renderer/classic fixture: 22/22 checks, including all 820 compiled fields
  measured with the real font, three-line bounds, scrolling/wrapping, repeated
  state purity, Champion status and started optional pages.
- Migrated v7 fixture: 14/14 checks, including immediate Story access, active
  Hoenn default and map/position restoration.
- `make modern` and `make validate`: exit 0. Build memory: EWRAM 235,256 bytes,
  IWRAM 28,216 bytes, ROM 22,977,184 bytes.
- `make check`: exit 0; 5,084 passed, 8 expected failing, 14 known failing,
  594 TODO (5,700 total). No unexpected failures.
- Graphical Start flag off: the four affected production modules compile with
  `PW_GRAPHICAL_START_MENU=0`; the classic caller is also exercised in-emulator.
- Full overworld sweep: **52/52**, exit 0, each sentinel freshly stamped with
  the shipping ROM hash (51 mandatory suites plus this machine's optional save).
- Final Frontier test: **19/19**, adding a save-counter provenance guard to the
  successful 18/18 run in the sweep. It verifies actual SAVE_NORMAL setup,
  completed SAVE_LINK, and regional/obstacle bytes across reboot/Continue.

The full sweep initially exposed two obsolete test assumptions. The quest-slot
assertion now opens the production Story renderer. The Frontier test previously
reset mid-write once it finally selected the real Save action; it now waits for
TrySavingData to finish. [Before/after evidence](regression-before-after.log).
No production save-code change was needed.

### Original captures

| View | Native capture |
|---|---|
| Three-campaign overview | [Overview](StoryProgress_01_overview.png) |
| Main next action | [Kanto chapter/action](StoryProgress_02_kanto_next.png) |
| Destination/prerequisite | [Kanto context](StoryProgress_03_kanto_where.png) |
| Established milestone/progress | [Kanto recap](StoryProgress_04_kanto_recap.png) |
| Another region without travel | [Johto](StoryProgress_05_johto_next.png), [Hoenn](StoryProgress_06_hoenn_next.png) |
| Classic Start caller | [Classic entry](StoryProgress_07_classic_story.png) |
| Champion with unfinished optional chain | [Overview](StoryProgress_08_champion_overview.png), [Main action](StoryProgress_09_champion_next.png) |
| Started optional action | [Optional next](StoryProgress_10_optional_next.png) |
| Optional context/recap | [Optional prerequisite](StoryProgress_11_optional_why.png) |

These are targeted fixtures, not continuous campaign playthroughs. See
[coverage and reproduction](../../../../docs/story-progress/README.md).
