# Review captures

Records screenshots and short videos of the game for visual review. A scene is a Lua script that
drives the headless emulator like a suite does. `Record.lua` wraps it and saves every second frame
as a PNG. The Python tools then turn frame ranges into MP4s, GIFs, stills and contact sheets.

Captures are not tests. They assert just enough to tell you that a scene reached the screen it
films, and they are not part of `run-all.sh` or the canonical case inventory.

## Requirements

- A built `pokemonworld.gba` and `pokemonworld.elf` at the repo root.
- The patched `mgba-headless` that the Lua suites use (see `../README.md`).
- `ffmpeg` and Python with Pillow.

## Usage

```bash
test/overworld/capture/rec.sh surf test/overworld/capture/scenes/SurfPikachu.lua
python3 test/overworld/capture/sheet.py surf 20
python3 test/overworld/capture/encode.py surf surfboard_catch 1:1532 --gif
python3 test/overworld/capture/still.py surf 421 surfboard_battle
```

Output goes to `build/capture/` unless `CAPTURE_OUT` names another folder:

- `bundle/` is a frozen copy of the ROM, ELF and symbols, made on the first `rec.sh` run. Later runs
  keep filming that copy even while the repo ROM is rebuilt. Delete it to film a new build.
- `runs/<name>/frames/` holds the PNG frames and `marks.txt`, which maps each `X.mark(label)` call in
  a scene to its frame number. Use the marks to choose `encode.py` ranges.
- `out/` holds the encoded MP4s (3x, 30 fps) and GIFs (2x, 15 fps), with stills in `out/stills/`.

`encode.py` refuses a clip longer than 60 seconds. `--hold N` repeats the last frame N times so the
final screen can be read (default 30).

The clock is pinned to `REC_RTC`, which defaults to a daytime value so outdoor maps are not tinted
for night.

## Scenes

| Scene | Films |
|---|---|
| `Intro.lua` | Gender choice and all 24 intro outfits. `REC_GENDER=girl` and `REC_PICK=<0..23>` vary it. |
| `Wardrobe.lua` | The World Transit wardrobe with Balloon Pikachu following. |
| `SurfPikachu.lua` | The Route 19 unlock and catch, the party and summary, then Surf against Swimmer Reece. |
| `Dex.lua` | Pikachu's and Squirtle's Forms pages and the Special Pokémon checklist. |
| `Followers.lua` | Six special Pokémon chosen with Follow, walked around Pallet Town and talked to. |
| `Story.lua` | The Story screen: overview, detail pages and destination map. |

Debug-menu setup runs while recording is off. Scenes show only real input.

## Writing a scene

```lua
local F, S, X = dofile(os.getenv("REC_TOOLS") .. "/Show.lua")("MyScene")
F.run(function()
  X.rec(false)
  assert(F.boot(100), "boot")
  -- setup off camera
  X.rec(true); X.mark("start")
  -- filmed input
  F.finish()
end)
```

`Show.lua` collects helpers copied from the suites: warps, debug Give with a four-digit species,
party decode and patching, talking, battle actions, Poké Balls and the party menu's Follow.
