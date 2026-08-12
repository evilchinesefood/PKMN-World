# Installing & Building Pokémon World

This is the complete setup and build guide for **Pokémon World**, a GBA ROM hack built on
[pokeemerald-expansion](https://github.com/rh-hideout/pokeemerald-expansion).

This repository **is** the project — you do not clone anything else. Building it produces
`pokemonworld.gba` at the repository root.

- **Output ROM:** `pokemonworld.gba` — 32 MB, ROM header title `POKEMON WRLD`, game code `BPEE`
  (`Makefile:2-3`)
- **Toolchain:** modern only — `arm-none-eabi-gcc` + newlib. **agbcc is not used**; the Makefile
  hardcodes `-DMODERN=1` and `make agbcc` deliberately exits with an error (`Makefile:345-348`).

For a project overview see [README.md](README.md); for the feature set see [FEATURES.md](FEATURES.md).

---

## 1. What the build actually needs

| Requirement | Why |
| --- | --- |
| `arm-none-eabi-gcc` + binutils (`as`, `ld`, `objcopy`, `objdump`, `nm`) | compiles and links the ROM |
| newlib for `arm-none-eabi` (`libc.a`, `libnosys.a`) | the modern link pulls `-lc -lnosys` (`Makefile:202`) |
| `make` | GNU make. macOS's bundled 3.81 works — see the caveat in §6 |
| a host C compiler (`cc` / `gcc`) | builds the 13 host tools in `tools/` |
| `libpng` **development headers** | `tools/gbagfx` and `tools/rsfont` `#include <png.h>` |
| `python3` | generates `wild_encounters.h`, `script_commands.h`, `symbols.lua`, and runs the validators |
| `git` | `make tools` runs `check_history.sh`, which **aborts if there is no git history** — clone the repo, do not use GitHub's "Download ZIP" (`touch .histignore` overrides it) |
| `libelf1` (Linux) | only for `make check` — the bundled `tools/mgba/mgba-rom-test` links against it |

Two `arm-none-eabi` toolchains are known to work: **devkitARM** (what this project is developed
with day to day) and the **GNU Arm Embedded** toolchain. Pick one; you do not need both.

WSL2 on Windows, native Linux, and macOS are all first-class. WSL1, Msys2 and Cygwin are
progressively much slower and are not supported here.

---

## 2. Platform setup

### Linux (Debian / Ubuntu)

This is the set CI installs, so it is the one that is continuously proven
(`.github/workflows/Check.yml`):

```console
sudo apt update
sudo apt install -y build-essential binutils-arm-none-eabi gcc-arm-none-eabi \
    libnewlib-arm-none-eabi libpng-dev python3 git
```

Add `libelf1` if you intend to run `make check`.

### Linux (Arch)

```console
sudo pacman -S --needed base-devel arm-none-eabi-gcc arm-none-eabi-binutils \
    arm-none-eabi-newlib libpng python git
```

### Linux (Fedora)

```console
sudo dnf install -y make gcc gcc-c++ arm-none-eabi-gcc-cs arm-none-eabi-newlib \
    libpng-devel python3 git
```

> The Arch and Fedora package names are best-effort — only the Debian/Ubuntu list above is
> exercised by CI on every push.

### Windows (WSL2)

```console
wsl --install
```

Then open the WSL shell and follow the **Linux (Debian/Ubuntu)** steps inside it.

### macOS (Apple silicon)

macOS already ships everything except libpng and the Arm toolchain. You do **not** need
Homebrew's `make` or `gcc`: the host tools build with Apple's `cc` and the bundled GNU Make.

```console
xcode-select --install          # if you have never installed the command line tools
brew install libpng zlib git python3
```

`zlib` is keg-only and macOS already ships libz — it is installed **purely for its `.pc` file**.
Homebrew's `libpng.pc` declares `Requires.private: zlib`, and `pkg-config --cflags libpng` fails
outright if it cannot resolve zlib, even though the header is right there.

Then install an Arm toolchain. Either works:

```console
brew install --cask gcc-arm-embedded     # arm-none-eabi-gcc + binutils + newlib, lands on PATH
```

or devkitPro's **devkitARM**, which is what this project is built with
(<https://devkitpro.org/wiki/Getting_Started>). devkitARM does *not* put `arm-none-eabi-gcc` on
your `PATH` — instead its installer exports `DEVKITARM`, and the Makefile picks that up and
prepends `$DEVKITARM/bin` for the duration of the build (`Makefile:75-85`). That is why
`which arm-none-eabi-gcc` can come back empty on a machine that builds this repo fine.

#### devkitPro users: set `PKG_CONFIG_PATH` before you build anything

**This will cost you an afternoon if you skip it.** devkitPro prepends `/opt/devkitpro/tools/bin`
to `PATH` and ships **its own `pkg-config`**, which searches only:

```console
$ pkg-config --variable pc_path pkg-config
/opt/devkitpro/tools/lib/pkgconfig:/opt/devkitpro/tools/share/pkgconfig
```

Homebrew's `libpng.pc` is in neither directory, so `pkg-config --cflags libpng` returns nothing,
`gbagfx` and `rsfont` compile with no `-I` for libpng, and you get:

```console
Package libpng was not found in the pkg-config search path.
...
convert_png.c:5:10: fatal error: 'png.h' file not found
    5 | #include <png.h>
      |          ^~~~~~~
```

The fix is one export. Put it in `~/.zshrc` **after** the devkitPro block:

```console
export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:/opt/homebrew/opt/zlib/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
```

Both entries are load-bearing: the first finds `libpng.pc`, the second finds the keg-only
`zlib.pc` that `libpng.pc` requires. With only the first, you get
`Package 'zlib', required by 'libpng', not found` and the same `png.h` failure.

Open a new shell and confirm before building:

```console
pkg-config --cflags --libs libpng
# -I/opt/homebrew/opt/libpng/include/libpng16 -I/opt/homebrew/opt/zlib/include -L/opt/homebrew/opt/libpng/lib -lpng16
```

See §6 for why this failure is so hard to read under `make -j`.

---

## 3. First-time repo setup

Install the git hooks. **Do this on every fresh clone** — git does not clone hooks, so until you
run this the pre-push gate is silently absent:

```console
Testing/hooks/install.sh
```

It symlinks `Testing/hooks/pre-push` into `.git/hooks/`. That hook runs six source-only
validators (a few seconds, no ROM build) that catch edits which build and boot cleanly and then
break in play:

| Check | Catches |
| --- | --- |
| `Testing/ValidateGen13.py` | references to disabled species |
| `Testing/ValidateScripts.py` | bare-integer script-pointer arguments |
| `Testing/ValidateOwMonPlacements.py` | bad overworld-Pokémon placements |
| `Testing/ValidateMapEvents.py` | object events with the wrong sprite / trainer / team |
| `Testing/GenObstacleTable.py --check` | a stale cleared-obstacle table |
| `Testing/SavePatch.py --check` | save-format constants that have drifted from the tree |

The same six run as `make validate`, and CI mirrors them in the `validate` job.

---

## 4. Verify the toolchain

```console
make --version
python3 --version
arm-none-eabi-gcc --version
```

If the last one says "not found", that is only a problem when you are **not** using devkitARM.
With devkitARM, check `echo $DEVKITARM` instead — as long as it points at a directory with a
`bin/` in it, the Makefile will find the compiler:

```console
$ echo $DEVKITARM
/opt/devkitpro/devkitARM
$ $DEVKITARM/bin/arm-none-eabi-gcc --version | head -1
arm-none-eabi-gcc (devkitARM) 16.1.0
```

---

## 5. Building

From the repository root:

```console
make modern -j8            # build pokemonworld.gba
```

`modern` is an explicit alias for the default target (`Makefile:340`) — plain `make` does exactly
the same thing. It is the spelling used by `Testing/mgba-run.sh` and `Testing/lua/MANIFEST.md`,
so it is the one used here too.

Pick `-j` to match your core count:

```console
make modern -j$(nproc)                      # Linux
make modern -j$(sysctl -n hw.ncpu)          # macOS — nproc does not exist here
```

> Do not copy `-j$(nproc)` onto macOS. `nproc` is not found, `$(nproc)` expands to nothing, and
> you silently get a bare `-j` — unlimited parallel jobs.

### Targets

| Target | What it does |
| --- | --- |
| `make` / `make modern` | build `pokemonworld.gba` (+ `.elf`, `.map`, and a refreshed `Testing/lua/symbols.lua`) |
| `make check` | build the test ELF and run the battle-engine suite in `test/` under mGBA |
| `make validate` | run the six host-side content validators (no build) |
| `make tools` | build only the host tools in `tools/` — the target to use when diagnosing a tools failure |
| `make symbols` | regenerate `Testing/lua/symbols.lua` from the ELF (the normal ROM build already does this) |
| `make obstacles` | regenerate the committed cleared-obstacle table after a map edit |
| `make debug` | same ROM filename, built with `-Og -g` into `build/emerald-debug` |
| `make release` | `pokemonworld-release.gba` — optimized, `NDEBUG`, LTO on by default (`config.mk`) |
| `make clean` | remove build artifacts, generated assets and host tools |
| `make tidy` | remove build artifacts only, keeping the tools and generated assets |

> **`make debug` overwrites `pokemonworld.gba`.** Only `release` renames its output
> (`Makefile:102-104`); `debug` changes the object directory but not the ROM filename.

> **`make release` is NOT the shipping build.** Project policy (2026-07-03, reaffirmed
> 2026-07-22 in `be8c2a4f`): releases ship the plain `make` dev build unchanged, debug menu
> included. A release build strips the debug menu that the test harness drives, turns
> `assertf`/`errorf` into no-ops, and LTO shifts every RAM address the Lua suites use — so it is
> untested territory. Don't distribute it without a dedicated QA pass.

### Expected output

The link step prints a memory-usage readout, then the command that produced it, then the
`gbafix` / `objcopy` lines that stamp and emit the ROM:

```console
Memory region         Used Size  Region Size  %age Used
           EWRAM:        ...          256 KB      ...
           IWRAM:        ...           32 KB      ...
             ROM:        ...           32 MB      ...
cd build/emerald && arm-none-eabi-ld -Map ../../pokemonworld.map --print-memory-usage --gc-sections -T ../../ld_script_modern.ld -o ../../pokemonworld.elf <objs> <libs> | cat
tools/gbafix/gbafix pokemonworld.elf -t"POKEMON WRLD" -cBPEE -m01 -r0 --silent
arm-none-eabi-objcopy -O binary pokemonworld.elf pokemonworld.gba
tools/gbafix/gbafix pokemonworld.gba -p --silent
```

A `warning: pokemonworld.elf has a LOAD segment with RWX permissions` from `ld` is expected and
harmless.

The region sizes come from `ld_script_modern.ld:9-11`. The `ROM:` line is the one worth watching
— the region is capped at 32 MB, and that percentage is the project's headroom budget.

On success the finished ROM is at the repository root as **`pokemonworld.gba`**
(33,554,432 bytes).

---

## 6. Troubleshooting

### `png.h: file not found`, or `Package libpng was not found`

Your `pkg-config` cannot see libpng. On macOS with devkitPro this is the norm, not an accident —
see §2. Confirm with `pkg-config --cflags libpng`, then export `PKG_CONFIG_PATH` as shown there.

### Hundreds of `tools/preproc/preproc: No such file or directory`

That is not the real error. Something failed while building the host tools — most often the
libpng problem above — and everything downstream then fails for the missing tool.

The Makefile *tries* to stop cleanly here (`Makefile:301-303` raises
`Errors occurred while building tools`), but that guard reads `.SHELLSTATUS`, which GNU Make
only sets from 4.2 onward. On macOS's bundled make it never fires:

```console
$ make --version | head -1
GNU Make 3.81
$ printf 'X := $(shell false)\n$(info [$(.SHELLSTATUS)])\nall: ;@true\n' > /tmp/t.mk && make -f /tmp/t.mk
[]
```

So on macOS the build sails past the failed tools step and floods the terminal, and under `-j`
the one line that matters has long since scrolled away.

**Always diagnose with `make tools` on its own.** It is a small serial build with nothing to
drown out the first error.

### `fatal: no git history found`

`make tools` runs `check_history.sh`, which refuses to build in a directory that is not a git
work tree. Clone the repository rather than downloading a ZIP; `touch .histignore` skips the
check if you really cannot.

---

## 7. Pointing the build at a toolchain elsewhere

By default the build uses whatever `arm-none-eabi-*` binaries are on `PATH`, plus `$DEVKITARM/bin`
if `DEVKITARM` is set. To use a toolchain somewhere else, pass `TOOLCHAIN` as a **make argument**:

```console
make TOOLCHAIN="/path/to/toolchain" modern
```

The directory must contain a `bin` subdirectory; that is what gets prepended to `PATH`
(`Makefile:82-85`).

> It must be on the command line. `TOOLCHAIN` is assigned inside the Makefile
> (`TOOLCHAIN := $(DEVKITARM)`, `Makefile:75`), and a makefile assignment beats an exported
> environment variable — `export TOOLCHAIN=...; make` has no effect. Only a command-line
> `make TOOLCHAIN=...` wins. Exporting `DEVKITARM` works, because that is the variable the
> Makefile reads.

This is also the no-root route: unpack a toolchain into your home directory and point
`TOOLCHAIN` at it, or just prepend it for one command:

```console
PATH=/path/to/toolchain/bin:$PATH make modern -j8
```

---

## 8. Pulling upstream expansion updates (optional)

This is a single, master-only project — there are no project branches to choose between. To pull
in newer pokeemerald-expansion changes, add RH-Hideout as a remote and merge (expect conflicts):

```console
git remote add RHH https://github.com/rh-hideout/pokeemerald-expansion
git pull RHH master
```

---

## 9. Useful additional tools

Optional editors that pair well with a pokeemerald-based project:

- [porymap](https://github.com/huderlem/porymap) — viewing and editing maps
- [poryscript](https://github.com/huderlem/poryscript) — scripting
  ([VS Code extension](https://marketplace.visualstudio.com/items?itemName=karathan.poryscript))
- [Tilemap Studio](https://github.com/Rangi42/tilemap-studio) — viewing and editing tilemaps
- [porytiles](https://github.com/grunt-lucas/porytiles) — adding new metatiles for maps
