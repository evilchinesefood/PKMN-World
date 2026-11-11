# Verification for issue 376

Issue 376 keeps automatic validation cheap and makes game verification an explicit choice. Build, Smoke and Full passed on macOS and Linux. Linux Full passed end-to-end on the final implementation commit. Two final test-tool corrections were also verified with focused macOS checks after its earlier Full run.

## Tested source and environment

Final implementation commit: `8b2896a7d391c28451c84e5cd09f2cf633bcb860`; source SHA256 `0ea1d373cb42d69132137fa736ed5c9b66dd0ebab393adc5c3af9362cfc2b0ec`; version `v1.7-141-g8b2896a7d3`. The clean final Linux Full run passed every stage. This documentation-only evidence commit follows that tested implementation; no functional code changed afterward.

The second Linux Full run tested clean commit `e4a14589ab0e3e47c0212c025498388b6d10fb17`, source SHA256 `0213b91c8574fe6550dd0c5bf634e417d95c429391d1d5f33dbd20c41148dcfd`, version `v1.7-140-ge4a14589ab`. Its 59/59 Lua suites and 24 boundary checks passed; GCC campaign export failed before Kanto gameplay.

Earlier implementation commit: `828c45acfd`. Its complete tracked source SHA256 is `2791f810d915885dc5960372ff43e3ecd0570d9753627e8c6b2e80f910e23663`, exactly matching the Linux Full snapshot. That run began before committing, so its recorded base is `ffd81ee868864507ffcb438fa0c72d7e83d514f6` and version is `v1.7-136-gffd81ee868-dirty`. Committing changed the Git/version metadata, not these source bytes.

The macOS Full and both final Smoke runs used source SHA256 `eec12b49122abca80e647741ed7b8a3a5044a750cf12b6897f482f528e8c48d2`. The subsequent changes are the World-playthrough README correction from inherited environment variables to explicit CLI arguments, the Lua-only Victory Road test isolation, and the GCC diagnostic handling in campaign export described below. No game source or save-format change is included.

- macOS 27.0.1 arm64; devkitARM GCC 16.1.0; eight build jobs.
- Linux: Ubuntu 24.04 x86-64, GCC ARM 13.2.1, Python 3.12.3 and CMake 3.28.3, unprivileged UID 1001 in a disposable Docker container. The source and Git metadata were read-only mounts; outputs stayed in the container's writable filesystem.
- Linux ran under x86 emulation on the ARM Mac. Timings are single-run capacity observations, not native GitHub-runner measurements or a speed comparison. Platform runs overlapped and shared host resources.

## Actual mode runs

| Platform | Mode | Result | Total seconds | Default build seconds | Lua seconds |
|---|---|---|---:|---:|---:|
| macOS | Build | Passed | 343.289 | 294.298 | Not selected |
| macOS | Smoke | Passed: 4 cases, 88 assertions | 231.399 | 186.742 | 16.202 |
| macOS | Full | Passed | 2293.051 | 212.459 | 430.165 |
| Linux emulated | Build | Passed | 1066.203 | 1022.524 | Not selected |
| Linux emulated | Smoke | Passed: 4 cases, 88 assertions | 1039.099 | 948.886 | 56.599 |
| Linux emulated | Full | Passed | 5656.748 | 825.437 | 556.398 |

Build summaries contained only the default build stage: no emulator bootstrap, Lua cases, TEST build or alternate flags. Smoke selected exactly SmokeBoot, WorldTitle, StoryProgress and RegionalTravelMigration. Mode-scope tests independently passed all three command plans.

Build and Smoke predate the final two test-tool corrections, which affect only Victory Road and campaign export. macOS Full predates those corrections; the affected suite and exporter were rechecked on macOS. Linux Full tests the final clean implementation end-to-end. The summaries retain each run's source identity rather than attributing earlier runs to the final commit.

Completed Full coverage on both platforms:

- Canonical inventory: 59 suites, 1,782 assertions, no failed cases. Counts were read from actual fresh verdicts, then independently accepted by the gallery evidence reader.
- Runner boundary checks: 24 passed.
- Kanto rival_lab, Johto rival_and_police and Hoenn route103: all selected losses and stop beats reached, retries disabled, active campaign/region and intended loss/recovery assertions passed.
- Host validation, save ABI probe and palette-sidecar dependency regression passed.
- Battle gate: 5,164 passed, 14 known failing, 594 TODO, 8 expected failing; 5,780 total. Exit status 0 on both platforms. Build plus tests took 613.846 seconds on macOS and 1567.288 seconds on emulated Linux.
- All three feature-off builds passed. macOS: Pokévial 240.721 seconds, field-move item gating 273.328, graphical start menu 277.522. Emulated Linux: 820.653, 792.949 and 893.089 seconds respectively.
- The final Linux summary contains 62 successful runtime cases and 1,841 assertions: the canonical 59/1,782 plus the three losses with 18, 21 and 20 assertions.

## Bootstrap and automatic checks

Both platforms built mGBA commit `669817d03e4858e65d0b992bcd96d3009236cc1e` with the committed patch and Lua 5.4.8, whose archive SHA256 is pinned. Final cold setup took 36.179 seconds on macOS and 102.417 seconds on emulated Linux. Final Smoke cache hits took 0.334 and 0.700 seconds respectively. Cache identity includes the recipe, patch, compiler, platform and dependency discovery; the binary hash is rechecked. Tools stayed under explicit cache prefixes.

Actual setup failures drove fixes before final runs: preserve pkg-config discovery, include the snapshot history marker, disable problematic emulator LTO under GCC 13, and bound Lua downloads with a checksum-verified mirror fallback. No assertions were relaxed.

The final host command passed 20/20 checks on both platforms with make, gmake, ARM tools and mGBA replaced by failing PATH stubs. Linux source was read-only. No blocked tool was invoked. Workflow syntax/actionlint, inventory tests and mode-scope tests passed. Every PR and master push runs the same stable host job, including documentation-only and mixed changes; there is no path filter or scheduled/indirect build trigger. Superseded PR checks cancel; master checks do not cancel each other.

This document records local pre-PR validation. The pull request's Checks tab records the actual automatic host job; manual dispatch and master-event limitations are stated below.

## Failure isolation and focused compatibility

The original focused runner returned success when `/usr/bin/true` produced no verdict. The new boundary rejects that case, stale PASS files, wrong ROM/ELF or symbols, missing/corrupt required fixtures, crashes, timeouts, empty or unreached selections, and conflicting inputs. Concurrent runs have separate evidence and cannot satisfy or clear each other's verdicts. Legacy v3/v4/v5 refusal fixtures use exact tracked hashes rather than applying an incompatible modern save ABI.

Focused checks exercised the final pinned emulator, ordinary and patched-art fixtures, seven Johto progression/core-loop cases, custom campaign beats, World loss selection, and gallery consumers. Additional fixture-boundary and publisher tests passed. Personal-save discovery and owner-save suites are excluded from both profiles.

## Linux Full failure investigation

The first Full run correctly failed at JohtoVictoryRoadTiles (29/30 assertions); the other 58 cases passed. An isolated rerun reproduced the same B1F movement failure. The identical Linux-built ROM passed on macOS. Instrumentation found a generated overworld encounter on the expected destination tile (17,17), outside the suite's static trainer assumptions. The correction isolates generated encounters for the field-control probe, preserving all rendering, trainer and exact destination assertions. The existing NationalParkTiles suite already uses that engine-safe technique. The fixed suite passed 30/30 on macOS and Linux using the previously built, bound ROMs. Independent review accepted the narrow patch without findings. The final clean Linux Full invocation subsequently passed all 59 suites. The failed run is retained as evidence, not relabeled or overwritten.

The second Linux run passed all 59 suites and 24 boundary checks, then failed in the campaign constant exporter. GCC reported an undeclared dependency in a header and the affected generated printf through a macro-expansion note; the old fallback recognized only Clang-style direct error locations. The correction recognizes both against the exact generated source path, removes only the unevaluable printf expression, and fails immediately if there is no removable expression. No numeric game constant was substituted.

After the fix, Linux and macOS produced byte-identical files containing 10,628 constants and all exported ARM ABI offsets. Linux preflight loss runs passed Kanto 18/18, Johto 21/21 and Hoenn 20/20, all with zero retries. Linux save ABI passed 73/73 and palette dependencies 4/4. Independent review accepted the exporter correction. The final Full invocation passed all of these gates in sequence, followed by battle checks and all three feature-off builds.

## Review and design

Two designs were compared; retaining existing runners with a shared strict case boundary scored 24/25 against 21/25 for a larger Python executor replacement. The selected design grafted immutable binding, exclusive output directories and a canonical TSV inventory without replacing the existing suites.

Independent correctness review found focused-caller compatibility issues, which were fixed and retested. Fresh review found no critical/major source findings; its remaining stale World README examples were corrected. Two comment reviews and additional focused reviews of both Linux fixes completed with no unresolved findings.

Principles applied: Model the Domain produced one explicit case table and input bundle; Laziness Protocol preserved existing runners; Prove It Works required actual platform modes and negative boundary probes. The throughput checkpoint grounded dependencies before implementation, delegated disjoint responsibilities through one owner, separated all mutable build/evidence outputs, and retained root-owned verification.

## Repository rules and limits

Live master branch protection returned 404, Branch not protected, and repository rulesets were empty. No rule changes were needed or made. The implementation PR remains unmerged.

The new manual workflow cannot be dispatched until present on the default branch. Local Linux execution proves the shared commands, not a GitHub manual-dispatch event. The changed master trigger and a separate documentation-only PR event cannot be observed before merge; their scope is established by workflow structure and host-only execution. No claim is made that those events ran.

These debug-assisted scenarios do not prove complete natural campaigns, all campaign permutations, balance or physical hardware behavior. Release documentation retains deliberate candidate verification. No ROM, ELF, save, screenshot or other build-output artifact is uploaded; detailed evidence stays local.

## Local evidence

Evidence remains under `/private/tmp/pkmn-376-evidence/`: `macos-modes/full-9pu4poz8/summary.json`, `linux-full-summary.json`, the three Linux Full evidence archives, and matching native bundles. The successful Linux archive retains all stage logs, case records, verdicts and screenshots; duplicate per-case ROM/save copies and build directories are excluded. The final summary records the exact bundle and emulator hashes and reproducible command.
