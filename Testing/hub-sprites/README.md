# World Hub NPC artwork — issue #330

The harbor master now uses `OBJ_EVENT_GFX_SAILOR_FRLG`, and the charm curator uses `OBJ_EVENT_GFX_GENTLEMAN_FRLG`. Both sheets already exist in the repository and match the room's FRLG art. These two fields in `data/maps/RegionHub/map.json` are the entire production change.

Open [the review gallery](review/index.html) in a browser through a local HTTP server. It contains native 240×160 comparisons, integer enlargement, lossless movement clips, all four directions, all twelve player outfits, representative follower service routes, and day/night Route 35/National Park captures. The [validation record](evidence/validation.md) includes exact sources, counts, fixture boundaries and limitations. [The approved specification](approved-spec.md) is retained unchanged.

## Five-minute owner review

1. Compare the harbor master and curator in the gallery and watch their walking/shadow clips.
2. Open the local playtest package's ROM with its matching `.sav`. It starts in the Hub with Pichu.
3. Talk to the harbor master from above. Walk around the left end of the service counters to the curator's north side and face down to talk. B declines his repeat-tour offer. Walk back past the central nurse with your follower.

The unmodified ROM and prepared save completed this route in `verify_delivery.lua`. No debug menu, personal save or fixture setup is required of the owner. The local download is available on the served gallery when its sibling `delivery.json` and ZIP are present. Build output is not stored in this repository.

## Reproduce

Requirements: the repository toolchain and Lua-enabled `mgba-headless` described in `Testing/mgba/README.md`, Python 3, and Pillow for the gallery. Run these commands from this worktree. Use an isolated worktree at the before revision for matched baseline captures; do not overwrite a personal ROM/save pair.

```sh
make modern TOOLCHAIN=/opt/devkitpro/devkitARM -j8
make release TOOLCHAIN=/opt/devkitpro/devkitARM -j8
make validate
PW_OUT=/tmp/hub-tracked Testing/run-all.sh

python3 Testing/hub-sprites/build_fixture.py \
  --repo "$PWD" --out /tmp/hub-fixture

for suite in HubSpritesComparison HubSpritesServices HubSpritesOutfits HubSpritesReadability; do
  run="$suite"
  if [ "$suite" = HubSpritesComparison ]; then run=after; fi
  PW_HUB_AFTER=1 python3 Testing/visual-features/run_fixture.py \
    --repo "$PWD" --fixture /tmp/hub-fixture \
    --suite "Testing/hub-sprites/$suite.lua" --out "/tmp/hub-runs/$run"
done

python3 Testing/visual-features/run_fixture.py \
  --repo "$PWD" --fixture /tmp/hub-fixture \
  --suite Testing/hub-sprites/save.lua --out /tmp/hub-runs/save
PW_OUT=/tmp/hub-runs/delivery Testing/mgba-run.sh \
  Testing/hub-sprites/verify_delivery.lua pokemonworld.gba \
  /tmp/hub-runs/save/VisualReview.sav
```

For the baseline, build `732f15cec3f8459da98c4d7076e72b084c4abda4` in a second worktree. Run this branch's `build_fixture.py` with `--repo` pointing at that worktree, then run this branch's `HubSpritesComparison.lua` against its fixture with `PW_HUB_AFTER=0` and `--out /tmp/hub-runs/before`. This omits the new-FRLG assertions while retaining follower/palette/resource checks. Keep both fixture manifests alongside the evidence.

```sh
python3 Testing/hub-sprites/render_review.py \
  --runs /tmp/hub-runs --out /tmp/hub-review \
  --before-source 732f15cec3f8459da98c4d7076e72b084c4abda4 \
  --after-source 388338478e17989b7428bbce07a7776ab23db9d3
```

Supply the actual source IDs if using different revisions. The renderer requires both labels, checks complete passing run verdicts, rejects ambiguous/missing screenshots and records media hashes. `capture-sources.json` records the chosen labels and all eleven matched pixel comparisons.

The fixture uses normal engine APIs for spawning, movement, warps, palettes and saving. Its commands are confined to `fixture.c`; the builder exports addresses from the matching ELF and uses the existing ROM-hash guard. `hub_lib.lua` records real active/visible events, loaded palettes and coordinates. Camera culling, day/night hiding, menu returns and the intro's temporary follower pocketing are accounted for explicitly.
