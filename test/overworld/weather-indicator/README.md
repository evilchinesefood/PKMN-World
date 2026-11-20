# Battle weather indicator suite

Covers issue #661. Upstream skips this UI under `TESTING`, so `make check` cannot see it. This
suite drives the production ROM in mGBA instead.

```sh
make modern -j8
test/overworld/weather-indicator/run.sh "$(mktemp -d)"
```

`run.sh` builds the shared [world-menu-theme fixture](../world-menu-theme/fixture.c) (case 43
seeds the lead with Rain Dance, Sunny Day, Hail and Sandstorm), reads the addresses it needs from
`pokemonworld.elf`, and runs [capture.lua](capture.lua) once in a wild single battle and once in
a wild double battle. It needs the patched `mgba-headless` described in
[the native verification guide](../mgba/README.md).

## What it checks

Singles:

- No weather draws nothing.
- Rain, sun, hail and sandstorm set by the real moves each show the icon on the next turn, and
  the icon leaves once actions are chosen.
- Bag and Party round trips remove the icon, restore it, and leave its palette intact.
- Heavy rain, harsh sun, strong winds, fog, snow and downpour, set by writing `gBattleWeather`.
- Clearing the weather removes the icon. Cloud Nine on the foe suppresses it.
- With every free sprite slot occupied the icon is skipped without a crash, and it appears once a
  slot frees up.
- Leaving the battle leaves no indicator task, and a second battle starts clean.

Doubles: sandstorm, snow and rain, Bag round trips with the palette check, the icon staying up
during move selection, battle exit and a second battle.

The palette check is the one that discriminates. Without the settled-screen guard in
`ShowWeatherIndicator`, doubles creates the sprite during the Bag transition and it ends up drawn
with a battler's palette. The suite then fails four doubles checks.

## Not covered

Primal Groudon, Primal Kyogre and Mega Rayquaza set their weather through abilities; the suite
sets the same weather flags directly instead. Air Lock shares the Cloud Nine code path and is not
run separately. Trainer battles, captures, fleeing by the Run command, losing a battle, task
exhaustion and palette-slot exhaustion are not exercised.
