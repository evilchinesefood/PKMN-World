# Releasing Pokémon World

Master is both the development branch and the release branch. Run the release gate deliberately
against the exact candidate commit. Automatic PR/master checks validate content only. They do
not establish that the game built or gameplay tests passed.

## 1. Verify the candidate

Start from the exact candidate, then run:

```sh
python3 test/validate-host.py
python3 test/verify.py full --jobs 8 --out /tmp/pw-release-checks --cache /tmp/pw-tools
```

The same Full mode is available through the manual [Verify workflow](.github/workflows/Verify.yml).
Its `revision` input can select the exact candidate commit. The workflow must already exist on
the default branch to dispatch it. [Native verification instructions](test/overworld/mgba/README.md)
cover dependencies, focused commands, and reading the result.

Every required check must pass:

1. Direct host/content validation, including the Story resolver and save-format checks.
2. The default shipping/dev build. Full builds this configuration once.
3. Every required Lua case in the [canonical inventory](test/overworld/cases.tsv), using the
   exact candidate ROM, matching ELF/symbols, and copied tracked fixtures. Missing or corrupt
   fixtures, omitted cases, stale or missing PASS results, and mismatched inputs fail the run.
4. The Kanto lab, Johto rival/police, and Hoenn Route 103 forced-loss cases. Each must reach its
   selected loss and stop beat, prove recovery or scripted continuation, and disable retries.
5. The complete battle-engine suite from `make check` in its isolated TEST configuration.
6. The palette-sidecar dependency regression and target save-layout probe.
7. Separate compile checks with `POKEVIAL_FEATURE`, `QOL_FIELD_MOVES_ITEM_GATE`, and
   `PW_GRAPHICAL_START_MENU` set to `FALSE`, one at a time.

Full is broad debug-assisted regression coverage. Add complete-campaign, postgame, natural-team,
or travel-route checks when the changes warrant them. It does not claim those checks ran by
itself. Personal-save tests are explicit local checks outside the canonical gate and never run
in CI.

Keep the summary and logs for this candidate. A pass requires exit zero and fresh matching
results for every selected case. Reuse valid evidence for the same revision/configuration;
do not rebuild merely because time passed. Any later code or configuration change needs
relevant new evidence.

## 2. Prepare the release notes

- Move CHANGELOG.md's `Unreleased` section under the new version and date.
- If `SAVE_FORMAT_VERSION` in `include/constants/global.h` changed, lead with the save-format
  change and state whether existing saves migrate or are refused.
- Check `SAVE_FORMAT_LAYOUT_MIN` too. Raising it refuses older layouts rather than migrating them.
- Match README.md and FEATURES.md version references to the new tag.

## 3. Tag the verified commit

- Create an annotated `vX.Y` tag, for example `git tag -a v1.5 -m "..."`.
- For a save-format bump, also tag the last commit of the previous format as
  `vX.Y-last-vN-save`. This leaves players a reproducible version that accepts their saves.
- After a save-format bump, open a new `Unreleased` section in CHANGELOG.md immediately.

## 4. Ship the default build

Ship the dev/default build from `make` or `make modern`. Do not switch to `RELEASE=1` or LTO.
The Lua suites use the debug menu, and release mode changes assertions and the memory layout.
The release configuration has not received the same QA. See [INSTALL.md](INSTALL.md#5-building).

Never upload build output from CI. Fan-project terms prohibit that distribution path. ROMs,
ELFs, saves, states, and screenshots stay in the runner's ephemeral workspace. Do not add
`actions/upload-artifact`. Distribution happens outside this repository.

When the new build refuses older saves, include this rollback note in the release post:

> Your save is refused by this version? It still works on the version that made it. Build the
> matching tag, for example `git checkout v1.3.6 && make`, and keep playing there. Starting a
> NEW GAME on the new version erases the old save.

## 5. Preserve the release record

- Verify that `git describe master` resolves to the new tag.
- Back up the printed verification run directory and personal play-saves to your chosen backup
  location. These are gitignored and are not uploaded by CI.
