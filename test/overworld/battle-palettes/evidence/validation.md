# Issue #327 validation

Game source: `05b37db1a9b1dd8efda95233e4a61822680bba7b`.
Merged base: `f1c1fd23921a6bc90618906ecdf3c629dc6ea34f`.
Before ROM source: `4bea54bfffd2ea73fcea7c34a4c36fede7cdceb2`.
The before source and merged base have identical `src`, `include`, `graphics`,
`data` and Makefile contents; intervening commits contain review evidence.
Final evidence/test-harness changes do not change the delivered game source.

## Results

| Check | Result |
|---|---|
| Development build | Pass |
| Release configuration build | Pass; delivery uses tested development build per `RELEASING.md` |
| Content validation | Exit 0; existing region-map mismatch notices remain |
| Battle engine | 5,084 pass; 14 pre-existing known failures; 594 TODO; 8 expected failures; 5,700 total |
| New feature + prepared-save delivery | 179/179 assertions |
| Matched palette comparisons | 58/58; UI, OBJ and gameplay environments unchanged in all 17 scenes |
| Existing BW UI integration | 514/514 assertions across all 15 suites |
| Tracked game sweep | 50/50 suites, all fresh and stamped with the delivery ROM MD5 |
| Rocket HQ Lance partner script | 7/7 assertions |
| Human-independent code review | No correctness/spec defects or hard standards violations; one non-blocking duplicate-branch observation |

The engine results differ from the previous BW baseline only by seven new
presentation tests and replacing one Camouflage TODO with an implemented
parameterized test. Nature Power, all four implemented Secret Power terrain
cases, and the new Camouflage cave/mountain/plain cases pass. Parameter rows
are exercised inside the named test; counts above use the runner's test totals.

`BattlePaletteCapture` covers all five Ice Path floors, both snowy Mt. Silver
maps, Granite Cave, noon/night in all three regions, morning/evening, and white,
dark and shiny Pokémon. The paired logs prove that all gameplay environment
IDs remain unchanged, including snow's original plain ID. UI BG 0–1/10–14 and
all OBJ palettes match the baseline. Noon and Granite Cave battlefield palettes
match too. `review/comparisons.json` records the independent log comparisons.

`BattlePaletteRestoration` passes 55 checks: initial/staged loaders, changed clock
with a frozen entry snapshot, Bag/Party returns at night/morning/evening, real
Grassy Terrain activation and normal five-turn expiry, Shadow Ball's temporary
background, and snow restoration. Loader probes compare every palette outside
BG 2–4 and verify that the gameplay environment does not change.

`BattlePaletteEntryEvolution` records real entrances and checks the shared
nonbattle loader by deliberately priming a stale snow snapshot before an actual
Eevee→Vaporeon evolution. Evolution clears the snapshot, uses the untinted plain
palette, completes, and returns to the field.

The memory regression reproduces on the merged baseline: one Bag or Party
return leaves the largest free block at 10,844 bytes, insufficient for the
13,024-byte terrain-image decompression. Initial allocation order is now reused
on return. Three repeated visits to each menu followed by Grassy Terrain pass;
no heap increase or retained menu buffers were introduced.

## Owner handoff

The local ZIP contains the unmodified production development ROM, its matching
synthetic Ice Path save, a manifest and a short play route. It contains no fixture
hook. The save starts at (19,24), an existing cave encounter tile. The unpatched
ROM was booted with this save and tested using normal inputs: walking → natural
Zubat encounter → Fight/L-info → Run → Ice Path. No writes or fixture commands
are used by `verify_delivery.lua`.

ROM SHA-256:
`4e144fe18d7ebb5c5466dd5ad03e9f76af5a27c31493db5034469dfcb532a95e`.
Other checksums are in `delivery.json`. ROMs and saves remain local and are not
committed or uploaded to GitHub.

## Evidence and limits

- All 53 gallery files come from actual 240×160 emulator frames. PNGs are copied
  unchanged. WebP clips are lossless, with every decoded frame/duration checked
  against the captured 20 fps timeline; no generated art or painted mockups.
- Fixture-only commands select maps, seed parties, set the existing clock
  override, or invoke specific loader probes. Ordinary capture encounters still
  use `BattleSetup_StartWildBattle` and real map environment selection.
- The final capture/restoration/UI suites use `fixture-manifest.json`. The later
  save fixture adds only command 206, placing the owner on an encounter tile;
  its hash is recorded separately in `save-fixture-manifest.json`.
- Special scenes are covered by resolver exclusions, the existing BW regression
  matrix, tracked Frontier/tutorial/healthbox suites, and the Lance partner test.
  This feature does not add a two-console cable battle test; the existing disabled
  Cable Club entry points and prior BW transport limitation remain unchanged.
- The optional personal-save suite is not run: this isolated worktree has no
  personal save. All 50 required tracked suites ran; no owner save was requested.
- Final owner review is visual preference and normal gameplay, approximately
  5–10 minutes. It is not a replacement for the automated engineering checks.

Commands and reproduction notes are in `../README.md`; individual results,
fixture manifests, build summaries, engine log and matching-ROM PASS sentinels
are committed alongside this report.
