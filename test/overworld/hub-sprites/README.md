# World Hub NPC artwork — issue #330

The harbor master now uses `OBJ_EVENT_GFX_SAILOR_FRLG`, and the charm curator uses `OBJ_EVENT_GFX_GENTLEMAN_FRLG`. Both sheets already exist in the repository and match the room's FRLG art. These two fields in `data/maps/RegionHub/map.json` are the entire production change.

Open [the review gallery](review/index.html) in a browser through a local HTTP server. It contains native 240×160 comparisons, integer enlargement, lossless movement clips, all four directions, all twelve player outfits, representative follower service routes, and day/night Route 35/National Park captures. The [validation record](evidence/validation.md) includes exact sources, counts, fixture boundaries and limitations. [The approved specification](approved-spec.md) is retained unchanged.

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
  PW_HUB_AFTER=1 python3 test/overworld/visual-features/run_fixture.py \
    --repo "$PWD" --fixture /tmp/hub-fixture \
    --suite "test/overworld/hub-sprites/$suite.lua" --out "/tmp/hub-runs/$run"
done

python3 test/overworld/visual-features/run_fixture.py \
  --repo "$PWD" --fixture /tmp/hub-fixture \
  --suite test/overworld/hub-sprites/save.lua --out /tmp/hub-runs/save
mkdir -p /tmp/hub-runs/delivery
PW_OUT=/tmp/hub-runs/delivery test/overworld/mgba-run.sh \
  test/overworld/hub-sprites/verify_delivery.lua pokemonworld.gba \
  /tmp/hub-runs/save/VisualReview.sav > /tmp/hub-runs/delivery/runner.log 2>&1
```

For the baseline, build `05b37db1a9b1dd8efda95233e4a61822680bba7b` in a second worktree. Run this branch's `build_fixture.py` with `--repo` pointing at that worktree, then run this branch's `HubSpritesComparison.lua` against its fixture with `PW_HUB_AFTER=0` and `--out /tmp/hub-runs/before`. This omits the new-FRLG assertions while retaining follower/palette/resource checks. Keep both fixture manifests alongside the evidence.

```sh
python3 test/overworld/hub-sprites/render_review.py \
  --runs /tmp/hub-runs --out /tmp/hub-review/review \
  --before-source 05b37db1a9b1dd8efda95233e4a61822680bba7b \
  --after-source 13478c088b0dcb2a28c3c453ed6eac0e8040364b
cp test/overworld/hub-sprites/README.md /tmp/hub-review/README.md
cp -R test/overworld/hub-sprites/evidence /tmp/hub-review/evidence
python3 -m http.server 8771 --bind 127.0.0.1 --directory /tmp/hub-review
```

Open `http://127.0.0.1:8771/review/`. The package root contains `README.md`,
`evidence/` and `review/`; the HTML's parent-relative evidence links resolve
inside this root. The optional local download also belongs at the root:
`delivery.json` contains `{"file": "YourBuild.zip"}`, and `YourBuild.zip` sits
beside it. Without these optional files, the download panel stays hidden.
Keep ROM/save packages outside the tracked repository.

Supply the actual source IDs if using different revisions. The renderer requires both labels, requires positive, complete verdicts and matching PASS sentinels for the baseline and feature runs, rejects ambiguous/missing screenshots and records media hashes. `capture-sources.json` records the chosen labels and all eleven matched pixel comparisons.

The fixture uses normal engine APIs for spawning, movement, warps, palettes and saving. Its commands are confined to `fixture.c`; the builder exports addresses from the matching ELF and uses the existing ROM-hash guard. `hub_lib.lua` records real active/visible events, loaded palettes and coordinates. Camera culling, day/night hiding, menu returns and the intro's temporary follower pocketing are accounted for explicitly.

Renderer boundary regressions can be rerun against a complete capture set:

```sh
python3 test/overworld/hub-sprites/check_renderer.py --runs /tmp/hub-runs
```

This deliberately supplies failed/zero-check baselines, missing/conflicting/stale
verdict sentinels and an aborted runner, then verifies UTF-8 under an ASCII
locale and every generated file link in the documented package layout.

Every run, including delivery, must retain its current `runner.log`. The shell
redirection above truncates delivery output before launch, so a ROM/hash guard
abort cannot reuse a previous success. A missing runner log fails preflight.
