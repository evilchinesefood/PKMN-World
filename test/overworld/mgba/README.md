# Run native verification on Linux or macOS

Run commands from the repository root. [INSTALL.md](../../../INSTALL.md) covers the ARM
compiler and normal game build. The [Lua manifest](../lua/MANIFEST.md) describes test coverage.

## Choose the work

Automatic PR and master checks run `python3 test/validate-host.py`. They validate tracked
content and native host behavior without installing an ARM compiler, building the game, or
starting an emulator. Documentation-only changes receive the same honest host result.

Game builds and gameplay verification require an explicit command or manual workflow run.
There are no scheduled builds or tests.

```sh
python3 test/verify.py build
python3 test/verify.py smoke --jobs 8 --out /tmp/pw-checks --cache /tmp/pw-tools
python3 test/verify.py full --jobs 8 --out /tmp/pw-checks --cache /tmp/pw-tools
```

Omitting the mode selects `smoke`.

| Mode | Work |
|---|---|
| `build` | One default shipping/dev build. No emulator, battle TEST build, or flag builds. |
| `smoke` | One default build, then SmokeBoot, WorldTitle, StoryProgress, and RegionalTravelMigration with its tracked fixture. |
| `full` | One default build, every canonical Lua case, three early forced-loss cases, battle checks, target save-layout checks, palette dependency regression, and the three feature-off builds. |

Full uses the [canonical case list](../cases.tsv). Each suite is classified as required or
manual, and host validation rejects missing rows and unclassified new suite files. TEST and each feature-off configuration have separate build trees. The default ROM
is shared by the selected Lua cases. Profiles copy source and record the checked-out commit
and local source identity. They never flip flags in the caller's checkout.

Smoke and Full are debug-assisted regression checks. They do not prove natural-team balance,
complete campaigns, postgame completion, or every campaign order. Full explicitly tests the
Kanto `rival_lab`, Johto `rival_and_police`, and Hoenn `route103` losses with retries disabled.
Each case must observe its selected loss, recovery or scripted continuation, and stop beat.
Any debug-assisted replay is named in its log.

## Prepare the emulator

Smoke and Full bootstrap their emulator into the selected cache directory. Build does not.
The bootstrap uses mGBA commit `669817d03e4858e65d0b992bcd96d3009236cc1e`, the committed
[headless patch](0001-headless-video-buffer-save-and-rtc.patch), and Lua 5.4.8 from a
checksum-verified source archive. The official Lua download is tried first; the MacPorts
source mirror supplies the identical pinned archive if that download fails. Verified source
archives are cached by SHA256 under the selected cache directory. It does not install into `~/.local/bin` or another global
user directory.

On Ubuntu, the manual workflow installs prerequisites with:

```sh
bash .github/scripts/install-toolchain.sh --emulator
```

On macOS, install the normal game toolchain from INSTALL.md, plus the native build dependencies:

```sh
brew install cmake pkg-config libpng
```

To prepare only the emulator and use it in focused runs:

```sh
export MGBA_HEADLESS="$(bash test/overworld/mgba/bootstrap.sh --prefix /tmp/pw-tools --jobs 8)"
```

The cache key includes the pinned sources, patch, platform, and compiler. It contains reusable
emulator tools, not saves, test results, or game builds. Setup logs go to stderr; stdout returns
the executable path. A failed or partial build is not a usable cache entry.

The patch supplies a video buffer for screenshots, autoloads the disposable fixture save,
and provides the deterministic `--rtc` clock. The bundled battle-test runner remains separate;
it does not provide the Lua engine used by these suites.

## Run focused checks

After a normal build, run a single suite or the canonical sweep without rebuilding the game:

```sh
test/overworld/mgba-run.sh test/overworld/lua/SmokeBoot.lua pokemonworld.gba
test/overworld/mgba-run.sh test/overworld/lua/VerifyV7Migrate.lua pokemonworld.gba test/overworld/lua/fixtures/v7dirty.srm
test/overworld/run-all.sh pokemonworld.gba
```

Use `--elf`, `--symbols`, and `--out` to select explicit inputs and an output parent. The runner
checks that the ELF reconstructs the ROM, then binds generated symbols to the copied ROM.
Each invocation creates a unique evidence directory. It never clears another run's sentinels.
A fixture is copied into a disposable save beside `Verify1.gba`; a missing fixture argument
means a fresh game. The runners do not discover or read personal saves. Current-layout
fixtures require intact sector checksums. The tracked v3/v4/v5 refusal fixtures predate that
layout, so their exact committed SHA256 identities are required instead; altered bytes fail.

The console clock defaults to `1704110400`, or 2024-01-01 12:00 UTC. Focused runs can select a
different epoch with `--rtc`. The clock advances with emulated frames, so day/night behavior
still runs. Use `--timeout` for a deliberate wall-clock limit. Profile cases ignore inherited
campaign, fixture, stop, loss, and retry selectors.

A pass requires process exit zero and a fresh PASS for the selected suite, with the executed
ROM's hash and positive, equal passed/total assertion counts. A crash, timeout, missing verdict,
FAIL sentinel, mismatched input, or missing required fixture fails the command.

Focused battle checks remain available through `make check TESTS='test name'`. Use GNU make
on macOS, normally `gmake`. See [RELEASING.md](../../../RELEASING.md) for the deliberate release gate.

## Run GitHub verification manually

Select **Actions > Verify on demand > Run workflow**, choose the workflow branch, and select
`build`, `smoke`, or `full`. The optional `revision` input selects a branch, tag, or exact commit
to check out. Blank uses the selected workflow ref. The run prints the resolved commit.

```sh
gh workflow run Verify.yml --ref master -f mode=smoke
gh workflow run Verify.yml --ref master -f mode=full -f revision=COMMIT_SHA
```

GitHub must have `Verify.yml` on the default branch before it can dispatch this workflow.
A premerge local Linux run is not evidence of a GitHub dispatch. The automatic host result
remains separate from manually requested gameplay evidence. No workflow uploads ROMs, ELFs,
saves, states, or screenshots.

## Read the evidence

Use the printed run directory and summary. They identify the commit, source/configuration,
mode, selected/passed/failed/excluded cases, input hashes, emulator, elapsed times, and
reproduction command. Setup, build, and test durations are separate. Reuse evidence only for
the same revision and configuration. A cached tool is not a cached test result.

Record measured timings with the candidate's verification notes. Include platform, compiler,
cache state, and whether Linux ran natively or under emulation. The workflow timeout is a
safety ceiling, not a promised completion time. Never weaken assertions to meet a time budget.
