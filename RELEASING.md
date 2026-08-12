# Releasing Pokémon World

The release checklist, pulled together from what used to live scattered across INSTALL.md
prose, `Check.yml` comments, and memory. It is built around save-format changes, because a
save-format change is this project's highest-consequence change class — it can strand players.

Master is both the dev branch and the release branch. There is no release branch to cut.

## 1. Preconditions — all must be green

1. **`make check`** — the battle-engine suite in `test/`. Locally, or via the CI `test` job.

2. **The full Lua sweep** — `Testing/run-all.sh`, against the exact commit being tagged:

   ```console
   make modern -j$(sysctl -n hw.ncpu)     # symbols.lua is a prerequisite of the ROM build
   Testing/run-all.sh
   ```

   Use `run-all.sh`, not `mgba-run.sh` — the latter runs a single suite. `run-all.sh` clears
   every `_pwtest/*.PASS` sentinel first, runs the whole battery, then requires each expected
   suite to have produced a *fresh* sentinel carrying the current ROM's md5. Suites that cannot
   run (missing fixture) are reported by name as SKIPPED and make the sweep exit non-zero, so a
   stale green cannot be counted. Anything short of a clean exit 0 is not a release.

   These suites run nowhere else — CI cannot run them (they need a locally patched Lua-enabled
   headless mGBA; see `Testing/mgba/README.md`). A release is the moment they must actually
   have run.

3. **`make validate`** — the six host-side content validators. The CI `validate` job mirrors
   them, and so does the `pre-push` hook if you installed it (`Testing/hooks/install.sh`).

4. **Default-config `make`** — the ROM that actually ships must build. CI `build` job.

5. **Feature-flag off-switches still compile** — CI `flag-matrix` job flips
   `POKEVIAL_FEATURE`, `QOL_FIELD_MOVES_ITEM_GATE` and `PW_GRAPHICAL_START_MENU` to `FALSE`
   one at a time and builds each. These rot invisibly; do not skip a red leg.

6. **CHANGELOG.md cut** — move the `Unreleased` section under a new version heading with
   today's date. If `SAVE_FORMAT_VERSION` (`include/constants/global.h:29`) changed since the
   last tag, that is the *headline* of the entry, with an explicit migration-or-refusal
   statement. Check `SAVE_FORMAT_LAYOUT_MIN` (`include/constants/global.h:44`) too — it is the
   oldest layout this build will load at all, and raising it refuses saves outright rather
   than migrating them.

7. **Docs sweep** — README.md / FEATURES.md version references match the new tag.

## 2. Tagging

- Tag the release commit `vX.Y`, **annotated** (`git tag -a v1.5 -m "..."`). Every existing
  release tag is annotated: `v1.0-beta`, `v1.3.6`, `v1.4`.
- If the release includes a save-format bump, also tag the last commit of the *previous*
  format `vX.Y-last-vN-save`, so a build of the old format stays one `git checkout` away for
  players whose saves the new build refuses. (Standing policy — no tag of this shape exists
  yet, so the first one sets the pattern.)
- After a save-format bump, open a fresh `Unreleased` section in CHANGELOG.md immediately.
  Leaving it until the next change is how the section drifts out of date.

## 3. Shipping

- Ship the **dev build** (`make` / `make modern`), not `make release`. Standing policy
  (2026-07-03, reaffirmed 2026-07-22; see [INSTALL.md §5](INSTALL.md#5-building)): the Lua
  harness drives the debug menu, `assertf`/`errorf` become no-ops in a release build, and LTO
  moves every RAM address the suites read. The release build has never had a QA pass. Revisit
  at 1.0.
- **Never upload build output from CI.** Fan-project terms — that is why `build.yml` was
  deleted in `25d26c50`, and why the note at the top of `.github/workflows/Check.yml` forbids
  adding `actions/upload-artifact`. Distribution happens outside this repo.

## 4. Player rollback note

Include this in the release post whenever the new build refuses older saves:

> Your save is refused by this version? It still works on the version that made it: build the
> matching tag (e.g. `git checkout v1.3.6 && make`) and keep playing there. Starting a NEW GAME
> on the new version erases the old save.

## 5. After the release

- Verify the tag resolves: `git describe master` should name the new tag.
- Back up `_pwtest/` and the personal play-saves off-machine. Both are gitignored
  (`.gitignore:11`, `.gitignore:99`) and exist on exactly one computer.
