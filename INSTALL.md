# Installing & Building Pokémon World

This file is the complete, self-contained setup and build guide for **Pokémon World** — a
GBA ROM hack built on [pokeemerald-expansion](https://github.com/rh-hideout/pokeemerald-expansion).

This repository **is** the project. You do not clone anything else: building it produces the
ROM `pokemonworld.gba` at the repository root.

- **Output ROM:** `pokemonworld.gba` (ROM header title `POKEMON WRLD`, game code `BPEE`)
- **Toolchain:** modern only — `arm-none-eabi-gcc` + newlib. **agbcc is not used.**

For a project overview see [README.md](README.md); for the feature set inherited from the
expansion see [FEATURES.md](FEATURES.md).

## 1. Prerequisites

This is a **modern-toolchain-only** build. You need the GNU Arm bare-metal toolchain plus the
usual build utilities. The recommended environment is **WSL2** on Windows (the dev environment
is aarch64 WSL); native Linux and macOS work too.

Required:

- `arm-none-eabi-gcc` — the Arm bare-metal C compiler
- `arm-none-eabi` **binutils** — `arm-none-eabi-as`, `-ld`, `-objcopy`, `-objdump`
- **newlib** for `arm-none-eabi` — provides `libc.a` and `libnosys.a` (required to link the
  modern target)
- `make`
- a host `gcc` / `g++` (used to compile the build tools in `tools/`)
- `python3`
- `libpng` (development headers) — for the graphics tools
- `git`

You do **not** need devkitARM or agbcc.

### Windows (WSL2)

1. Install WSL2 with a Linux distribution (Ubuntu is fine):

   ```console
   wsl --install
   ```

2. Open the WSL shell and follow the **Linux (Debian/Ubuntu)** steps below from inside it.

> WSL2 is strongly recommended. WSL1, Msys2, and Cygwin are progressively (much) slower and are
> not supported here.

### Linux (Debian / Ubuntu)

```console
sudo apt update
sudo apt install -y build-essential binutils-arm-none-eabi gcc-arm-none-eabi \
    libnewlib-arm-none-eabi git libpng-dev python3
```

`gcc-arm-none-eabi` pulls in the compiler and binutils; `libnewlib-arm-none-eabi` provides
`libc.a` / `libnosys.a` for the modern link.

### Linux (Arch)

```console
sudo pacman -S --needed base-devel arm-none-eabi-gcc arm-none-eabi-binutils \
    arm-none-eabi-newlib git libpng python
```

### Linux (Fedora)

```console
sudo dnf install -y make gcc gcc-c++ arm-none-eabi-gcc-cs arm-none-eabi-newlib \
    git libpng-devel python3
```

### macOS

```console
brew install make gcc python3 libpng git
brew install --cask gcc-arm-embedded   # arm-none-eabi-gcc + binutils + newlib
```

### Verify the toolchain is on PATH

```console
arm-none-eabi-gcc --version
make --version
python3 --version
```

If `arm-none-eabi-gcc` is found, you are ready to build.

### Alternative: user-space toolchain (no system install / no root)

If you can't (or don't want to) install the toolchain system-wide, you can drop an
`arm-none-eabi` toolchain into your home directory and put it on `PATH` only for the build.
This project is known to build cleanly with a user-space toolchain laid out under
`~/.local/arm-none-eabi/`:

```console
PATH=~/.local/arm-none-eabi/usr/bin:$PATH make -j$(nproc)
```

This is the same as the standard build below — it just prepends the user-space toolchain to
`PATH` for that one command, so no `sudo` is required. See
[Overriding the toolchain](#overriding-the-toolchain) for the `TOOLCHAIN` variable as another
way to point the build at a toolchain in a non-default location.

## 2. Building

From the repository root:

```console
make -j$(nproc)         # build pokemonworld.gba (the default target)
make -j$(nproc) check   # build, then run the battle-engine test suite (test/)
make clean              # remove build artifacts
make debug              # build pokemonworld.elf with debug symbols + debug-friendly optimization
```

`make` with no target builds the ROM. `make check` adds the test runner (the `test/` battle
mechanics suite). `make debug` produces an ELF with `-Og -g` for use in a debugger.

> `-j$(nproc)` runs a parallel build using all CPU cores. See
> [Parallel builds](#parallel-builds) if `nproc` isn't available (e.g. macOS).

### Expected output

When the link step runs you'll see a memory-usage readout, followed by the `gbafix` /
`objcopy` lines that stamp and emit the ROM. It looks roughly like this (exact byte counts
will drift as the project changes):

```console
arm-none-eabi-ld: warning: ../../pokemonworld.elf has a LOAD segment with RWX permissions
Memory region         Used Size  Region Size  %age Used
           EWRAM:      243xxx B       256 KB     ~93%
           IWRAM:       30xxx B        32 KB     ~93%
             ROM:    26xxxxxx B        32 MB     ~78%
cd build/modern && arm-none-eabi-ld  -T ../../ld_script_modern.ld --print-memory-usage -o ../../pokemonworld.elf <objs> <libs> | cat
tools/gbafix/gbafix pokemonworld.elf -t"POKEMON WRLD" -cBPEE -m01 -r0 --silent
arm-none-eabi-objcopy -O binary pokemonworld.elf pokemonworld.gba
tools/gbafix/gbafix pokemonworld.gba -p --silent
```

On success the finished ROM is written to the repository root as **`pokemonworld.gba`**
(a 32 MB / 33,554,432-byte file). The `ROM:` line of the memory readout is worth watching —
the ROM region is capped at 32 MB, so the percentage there is the project's headroom budget.

## 3. Building guidance

### Parallel builds

To speed up the build, pass `-j` with your core count. Get the count with:

```console
nproc
```

then build with, for example:

```console
make -j8
```

`make -j$(nproc)` does both in one line. `nproc` is not available on macOS — use
`sysctl -n hw.ncpu` instead, e.g. `make -j$(sysctl -n hw.ncpu)`.

See the [GNU make parallel-build docs](https://www.gnu.org/software/make/manual/html_node/Parallel.html)
for details.

### Overriding the toolchain

By default the build uses `arm-none-eabi-*` binaries found on `PATH`. To build with a toolchain
in a non-standard location, set the `TOOLCHAIN` environment variable to a directory that
contains a `bin` subdirectory:

```console
make TOOLCHAIN="/path/to/toolchain"
```

For example:

```console
make TOOLCHAIN="/usr/local/arm-none-eabi"
```

For the modern target the toolchain directory must also contain the `lib`, `include`, and
`arm-none-eabi` subdirectories.

### Pulling upstream expansion updates (optional)

This is a single, master-only project — there are no project branches to choose
between. If you ever want to pull in newer pokeemerald-expansion changes, add RH-Hideout as a
remote and merge from it (expect to resolve conflicts):

```console
git remote add RHH https://github.com/rh-hideout/pokeemerald-expansion
git pull RHH master
```

## 4. Useful additional tools

These are optional editors/tools that pair well with a pokeemerald-based project:

- [porymap](https://github.com/huderlem/porymap) — viewing and editing maps
- [poryscript](https://github.com/huderlem/poryscript) — scripting
  ([VS Code extension](https://marketplace.visualstudio.com/items?itemName=karathan.poryscript))
- [Tilemap Studio](https://github.com/Rangi42/tilemap-studio) — viewing and editing tilemaps
- [porytiles](https://github.com/grunt-lucas/porytiles) — adding new metatiles for maps
