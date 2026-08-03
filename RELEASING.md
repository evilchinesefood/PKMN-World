# Releasing Pokémon World

The checklist that was previously scattered across INSTALL.md prose, Check.yml comments,
and memory. Added by the 2026-08-02 deep review (fixes.md task 42). A save-format change
is this project's highest-consequence change class — it can strand players — so the
checklist is built around it.

## Preconditions (all must be green)

1. **`make check`** — the battle-engine suite, locally or via the CI `test` job.
2. **The full Lua sweep** — every suite in `Testing/lua/MANIFEST.md` via
   `Testing/mgba-run.sh`, against the exact commit being tagged. These are enforced
   nowhere else; a release is the moment they must actually have run.
3. **`make validate`** — the four host-side validators (CI mirrors these).
4. **Default-config `make`** — the shipping ROM builds (CI `build` job).
5. **CHANGELOG.md cut** — move the `Unreleased` section under a new version heading with
   today's date. If `SAVE_FORMAT_VERSION` changed since the last tag, that fact is the
   headline of the entry, with a migration-or-refusal statement.
6. **Docs sweep** — FEATURES.md / README.md version references match the new tag.

## Tagging

- Tag the release commit `vX.Y` (annotated). If the release includes a save-format bump,
  also tag the last commit of the *previous* format `vX.Y-last-vN-save` so a player build
  of the old format stays one `git checkout` away.
- Master is both the dev and the release branch; after tagging, the next save-format bump
  starts a new `Unreleased` CHANGELOG section immediately (see task 20's drift).

## Shipping

- Ship the **dev build** (`make`), not `make release` — standing policy (2026-07-03,
  reaffirmed 2026-07-22; see INSTALL.md §2): the harness drives the debug menu, and the
  release build has never had a QA pass. Revisit at 1.0.
- Never upload build output from CI (fan-project terms; see the 25d26c50 note in
  Check.yml). Distribution happens outside this repo.

## Player rollback note (include in release posts when saves are refused)

> Your save is refused by this version? It still works on the version that made it:
> build the matching tag (e.g. `git checkout v1.3.6 && make`) and keep playing there.
> Starting a NEW GAME on the new version erases the old save.

## After the release

- Verify `git describe` on master resolves to the new tag.
- Back up `_pwtest/` and the personal play-saves off-machine (they are gitignored and
  exist on exactly one computer — see fixes.md task 41f).
