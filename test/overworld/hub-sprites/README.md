# World Hub NPC artwork — issue #330

> **Note.** The run output this page cites (logs, screenshots and review pages) was removed from the repository in November 2026. It is still in git history before that removal. The results below are the record.

The harbor master now uses `OBJ_EVENT_GFX_SAILOR_FRLG`, and the charm curator uses `OBJ_EVENT_GFX_GENTLEMAN_FRLG`. Both sheets already exist in the repository and match the room's FRLG art. These two fields in `data/maps/RegionHub/map.json` are the entire production change.

Open the review gallery in a browser through a local HTTP server. It contains native 240×160 comparisons, integer enlargement, lossless movement clips, all four directions, all twelve player outfits, representative follower service routes, and day/night Route 35/National Park captures. The validation record includes exact sources, counts, fixture boundaries and limitations. [The approved specification](approved-spec.md) is retained unchanged.

## Five-minute owner review

1. Compare the harbor master and curator in the gallery and watch their walking/shadow clips.
2. Open the local playtest package's ROM with its matching `.sav`. It starts in the Hub with Pichu.
3. Talk to the harbor master from above. Walk around the left end of the service counters to the curator's north side and face down to talk. B declines his repeat-tour offer. Walk back past the central nurse with your follower.

The unmodified ROM and prepared save completed this route in `verify_delivery.lua`. No debug menu, personal save or fixture setup is required of the owner. The local download is available on the served gallery when its sibling `delivery.json` and ZIP are present. Build output is not stored in this repository.

## Reproduce

Requirements: the repository toolchain and Lua-enabled `mgba-headless` described in `test/overworld/mgba/README.md`, Python 3, and Pillow for the gallery. Run these commands from this worktree. Use an isolated worktree at the before revision for matched baseline captures; do not overwrite a personal ROM/save pair.

```sh
make modern TOOLCHAIN=/opt/devkitpro/devkitARM -j8
make release TOOLCHAIN=/opt/devkitpro/devkitARM -j8
make validate
PW_OUT=/tmp/hub-tracked test/overworld/run-all.sh

python3 test/overworld/hub-sprites/build_fixture.py \
  --repo "$PWD" --out /tmp/hub-fixture

for suite in HubSpritesComparison HubSpritesServices HubSpritesOutfits HubSpritesReadability; do
  run="$suite"
  if [ "$suite" = HubSpritesComparison ]; then run=after; fi
  python3 test/overworld/visual-features/run_fixture.py \
    --repo "$PWD" --fixture /tmp/hub-fixture \
    --suite "test/overworld/hub-sprites/$suite.lua" --out "/tmp/hub-runs/$run" --env PW_HUB_AFTER=1
done

python3 test/overworld/visual-features/run_fixture.py \
  --repo "$PWD" --fixture /tmp/hub-fixture \
  --suite test/overworld/hub-sprites/save.lua --out /tmp/hub-runs/save
python3 test/overworld/viridian-art/run_suite.py --repo . \
  --suite test/overworld/hub-sprites/verify_delivery.lua --rom pokemonworld.gba \
  --save /tmp/hub-runs/save/VisualReview.sav --out /tmp/hub-runs/delivery
```

For the baseline, build `05b37db1a9b1dd8efda95233e4a61822680bba7b` in a second worktree. Run this branch's `build_fixture.py` with `--repo` pointing at that worktree, then run this branch's `HubSpritesComparison.lua` against its fixture with `--env PW_HUB_AFTER=0` and `--out /tmp/hub-runs/before`. This omits the new-FRLG assertions while retaining follower/palette/resource checks. Keep both fixture manifests alongside the evidence.

The review renderer and its regression check were removed on 2026-11-16. The notes below describe the
package they produced. The package root contains `README.md`,
`evidence/` and `review/`; the HTML's parent-relative evidence links resolve
inside this root. The optional local download also belongs at the root:
`delivery.json` contains `{"file": "YourBuild.zip"}`, and `YourBuild.zip` sits
beside it. Without these optional files, the download panel stays hidden.
Keep ROM/save packages outside the tracked repository.

The renderer required both source labels, required positive, complete verdicts and matching PASS sentinels for the baseline and feature runs, rejected ambiguous/missing screenshots and recorded media hashes. `capture-sources.json` recorded the chosen labels and all eleven matched pixel comparisons.

The fixture uses normal engine APIs for spawning, movement, warps, palettes and saving. Its commands are confined to `fixture.c`; the builder exports addresses from the matching ELF and uses the existing ROM-hash guard. `hub_lib.lua` records real active/visible events, loaded palettes and coordinates. Camera culling, day/night hiding, menu returns and the intro's temporary follower pocketing are accounted for explicitly.

Every run, including delivery, must retain its current `runner.log`.
`run_fixture.py` and `run_suite.py` require a fresh, empty `--out` directory and
write `runner.log` there, so a ROM-hash guard abort cannot reuse a previous
success. A missing runner log fails preflight.
