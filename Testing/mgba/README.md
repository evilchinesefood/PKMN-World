# Running the Lua suites on macOS (mGBA stand-in for BizHawk)

`Testing/BizHawkTesting.md` is the field guide for the suites themselves — boot signals, the
debug menu, warp byte order, collision checking. All of that still applies. **This file only
covers the emulator**, because on macOS the emulator is not BizHawk.

Status: this setup is what every tracked suite runs on. The last full sweep on this machine
(`Testing/run-all.sh`, ROM md5 `0887BE3D…`, 2026-08-12) was **20/20 expected suites green, 549
assertions**, in about 90 seconds. The sweep still exits **non-zero**: one suite has no fixture in
the tree and one needs an untracked save — [`../lua/MANIFEST.md`](../lua/MANIFEST.md) explains both.

## Why not BizHawk

There is no macOS build of BizHawk. Upstream ships Windows and Linux only; there is no
Homebrew formula or cask, and no Apple Silicon target. The suites therefore run under mGBA's
**headless** frontend, which is CLI-driveable and has a Lua engine, with
`Testing/lua/mgba_shim.lua` providing the EmuHawk API the suites were written against.

Three candidates were evaluated on this machine:

| | headless CLI | Lua | usable |
|---|---|---|---|
| BizHawk / EmuHawk | — | — | no macOS build at all |
| mGBA.app 0.10.5 (Homebrew cask) | no `--script` flag | yes | GUI only, manual |
| `tools/mgba/mgba-rom-test-mac` (in repo) | `--script` present | **no engine linked** | `Failed to load script` |

So the shipped rom-test binary advertises `--script` but was compiled without Lua, and the
released GUI app has Lua but no way to load a script from the command line. Neither works
unattended. The fix is a purpose-built binary.

## Building `mgba-headless`

`--script` only reached the headless frontend after the 0.10.5 release, so this must be built
from **master**, not the 0.10.5 tag. In master the tool was also renamed: `mgba-rom-test` →
`mgba-headless` (`BUILD_ROM_TEST` → `BUILD_HEADLESS`).

```bash
brew install cmake lua libpng            # zlib too, if pkg-config can't find it
git clone https://github.com/mgba-emu/mgba.git
cd mgba
git apply /path/to/PKMN-World/Testing/mgba/0001-headless-video-buffer-save-and-rtc.patch

cmake -S . -B build \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_HEADLESS=ON -DENABLE_SCRIPTING=ON -DUSE_LUA=ON \
  -DBUILD_QT=OFF -DBUILD_SDL=OFF -DUSE_FFMPEG=OFF -DUSE_DISCORD_RPC=OFF \
  -DBUILD_SHARED=OFF -DBUILD_STATIC=ON
cmake --build build -j$(sysctl -n hw.ncpu) --target mgba-headless
cp build/mgba-headless ~/.local/bin/
```

`-DCMAKE_POLICY_VERSION_MINIMUM=3.5` is required: mGBA's `cmake_minimum_required` predates 3.5
and CMake 4.x refuses it outright. `BUILD_SHARED=OFF` makes the binary standalone rather than
needing `DYLD_LIBRARY_PATH` to find `libmgba.dylib`.

Built and verified against upstream `669817d03e4858e65d0b992bcd96d3009236cc1e` with Lua 5.5.0.

### The patch

The headless frontend is much less exercised than Qt/SDL, and it omits three things they all
do. None of the three produces a diagnostic — each just silently changes behaviour.

1. **No video buffer.** `core->setVideoBuffer` was never called, so the core rendered into a
   null pointer. `emu:screenshot()` wrote a valid 33-byte PNG header and then segfaulted the
   process mid-encode. Compare `src/platform/test/perf-main.c` and `src/platform/sdl`.

2. **No `mCoreAutoloadSave`.** The battery save beside the ROM was never attached, so *every*
   run started from an empty save regardless of what was on disk. A suite pointed at a save
   fixture booted to NEW GAME and reported `BOOT FAIL`, which reads as a game-side regression.
   `VerifyV7Migrate` scored 0/1 before this line and 10/10 after, with no change to the ROM or
   the suite. Compare `qt/CoreManager.cpp:152`, `sdl/main.c:210`, `psp2-context.c:645`.

3. **No way to pin the clock**, added here as `--rtc SECONDS`. See *Determinism* below.

## Running a suite

```bash
Testing/mgba-run.sh Testing/lua/SmokeBoot.lua
Testing/mgba-run.sh Testing/lua/VerifyV7Migrate.lua pokemonworld.gba Testing/lua/fixtures/v7dirty.srm
```

Arguments are `<suite.lua> [rom.gba] [save.srm]`; the ROM defaults to the repo build. Exit code
is 0 on pass, 1 on suite failure, 2 on a setup error. Evidence lands in `_pwtest/`
(`.log`, `.PASS`/`.FAIL`, numbered `.png` screenshots).

To run everything instead of one suite:

```bash
Testing/run-all.sh
```

That is the only thing that produces a trustworthy count — it clears the sentinels first and then
requires each suite to have written a fresh `.PASS` stamped with the current ROM's md5. Its exit
code and the two structural reasons it fails on a clean checkout are documented in
[`../lua/MANIFEST.md`](../lua/MANIFEST.md). Neither script runs in CI; the suites are a local gate
only.

The runner copies the ROM into a throwaway directory under a `Verify1` name before driving it.
That is not ceremony — it satisfies `lib.lua`'s `ROM_ALLOWLIST` and enforces
`BizHawkTesting.md` §2, since a suite blind-presses A and Start for thousands of frames and the
save wheel has SAVE at slot 2. Any save the run writes dies with the temp directory.

## Determinism

Runs are reproducible because the runner pins the console clock, defaulting to
`--rtc 1704110400` (2024-01-01 12:00:00 UTC). Override with `PW_RTC=<unix-seconds>` to exercise
a different in-game time.

This matters more than it sounds. Emerald seeds its RNG from the RTC at boot, and the seed
drives NPC movement — which is precisely what blocks a coordinate-verified walk. With the clock
left on wall time, `TinTowerRoof` scored 3/5, 27/27, 27/27 on three identical back-to-back runs.
With it pinned, five consecutive runs all scored 27/27, and two full sweeps (18 suites at the time
of measuring) produced byte-identical output.

`--rtc` uses `RTC_FAKE_EPOCH`, not `RTC_FIXED`: the clock starts at the requested instant and
then advances off the *emulated frame counter*. So it is reproducible and still monotonic, which
the day/night suites need — a frozen clock would hang anything waiting for time to pass.

## What the shim does

`Testing/lua/mgba_shim.lua` is the `--script` entry point; it loads the suite named by
`$PW_SUITE`. It reconciles four differences:

- **Callback vs straight-line.** mGBA runs a script's main chunk once, before emulation, then
  fires `callbacks:add("frame", ...)`. BizHawk suites block in `emu.frameadvance()`. The suite
  runs inside a coroutine resumed once per frame; `frameadvance()` is `coroutine.yield()`.

- **Unaligned reads.** This one silently corrupts data rather than erroring. mGBA models the
  GBA's misaligned-access behaviour: a 16/32-bit read off a boundary reads the containing
  aligned word and *rotates* it, so `emu:read16(0x080000A1)` returns `0x5000004F` where the two
  bytes there spell `0x4B4F`. BizHawk's `memory.read_u16_le` reads the bytes AT the address.
  `struct ObjectEventTemplate` is `__attribute__((packed))` with `graphicsId` at offset **+1**,
  so every template scan reads a u16 from an odd address — forwarding straight through made
  `OwMonSprites` report "0/N real species" on all seven maps. The shim composes unaligned
  accesses byte-wise and fast-paths aligned ones.

- **Methods vs free functions.** `emu:read32(a)` becomes `memory.read_u32_le(a)`, and the
  BizHawk domain argument (`"System Bus"`) is accepted and ignored — mGBA reads are already
  bus-addressed.

- **Key indices vs masks.** `C.GBA_KEY.*` are bit *indices* (A=0 … L=9); `emu:setKeys()` wants
  a mask, so every lookup goes through `1 << index`. Passing the index straight through happens
  to work for `A` (bit 0) and silently presses the wrong button for everything else — `Start`
  would register as `Right`.

`console.log` writes to stdout directly rather than through `mconsole:log`, because the runner
passes `-l 0` to silence mGBA's per-DMA/BIOS chatter and that mask would swallow suite output
with it, making a run look silent and passing whether or not it did anything.

## Note on the SaveBlock1 offsets

`BizHawkTesting.md` §4 warns that the annotated struct offsets in `include/global.h` are stale.
For `objectEventTemplates` that turned out **not** to be true on this build — an `offsetof`
probe compiled with the repo's exact CFLAGS (`-mabi=apcs-gnu -mthumb -O2 -std=gnu17`) confirms
`3988` / `0xF94`, matching both the annotation and `OwMonSprites`'s constant. The template
scan was failing for the unaligned-read reason above, not a bad offset. Re-probe rather than
assume if a scan ever comes back empty:

```bash
printf '#include "global.h"\n#include <stddef.h>\nconst unsigned P = offsetof(struct SaveBlock1, objectEventTemplates);\n' > /tmp/p.c
$DEVKITARM/bin/arm-none-eabi-gcc -iquote include -DMODERN=1 -DEMERALD -DALL_REGIONS=1 -DTESTING=0 \
  -mthumb -mthumb-interwork -O2 -mabi=apcs-gnu -march=armv4t -std=gnu17 -S -o - /tmp/p.c | grep -A1 '^P:'
```
