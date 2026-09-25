# Pokémon World branding

`logos/pokemon-world.png` is the shared stacked logo used by the main README and
the title exporter. World is intentionally shifted right relative to Pokémon:
44 pixels in the 1774-pixel master, producing the approved 4-pixel offset when
the logo is rendered 160 pixels wide in-game. Keep the overall stack centered;
PRESS START remains centered on the screen independently.

After editing the master, run:

```sh
node tools/export-world-title.mjs
make modern -j8
Testing/mgba-run.sh Testing/lua/WorldTitle.lua
```

The exporter rebuilds the native title resources and the legacy
`.github/pokemon_world_logo.png` thumbnail. It checks the wordmark's offset and
the GBA palette, tilemap and VRAM limits. Refresh
`screenshots/01-title-screen.png` from the emulator after a title change.

`box/box-front.png` is a flattened cover with the same proportional adjustment
to World (19 pixels at its printed size). `logos/world.png` is the standalone
wordmark: it has no Pokémon lettering to align against and keeps its own center.
