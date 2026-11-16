# Version 12 cross-region damage fixtures

Both saves were written by `origin/master` at `bcfc96d860`, before the fixes in #602 (Goldenrod's
first visit cleared `FLAG_RECEIVED_BIKE`) and #604 (the Johto PokeGear set `FLAG_RECEIVED_POKENAV`).
The default `make modern` ROM had MD5 `6cab463b310366385b81f94417a9cbd3`. Each came from a fresh
new game driven by `test/overworld/lua/XRegionDamageFixtures.lua`, run from inside that build's own
tree, and was saved through the normal Start menu Save. The damage is what the old scripts wrote; the
only debug setup is warps, the Stone Badge flag and one party Pokemon. No personal save was used.

`v12xregiondamaged.srm` (`PW_XREGION_CASE=damaged`): the mother's PokeGear in New Bark, Rydel's
Mach Bike, the first walk into Goldenrod (the flag is cleared with the Mach Bike still in the Bag),
then Hoenn with the first badge: the Rustboro Pokemon Center recorded `VAR_BRINEY_LOCATION = 1`, and
leaving by Hub Pass and coming back through the Hoenn gate cleared Mr. Briney's and Peeko's cottage
hide flags. Saved inside the cottage with both of them standing in the object list.

`v12xregionvoyage.srm` (`PW_XREGION_CASE=voyage`): the same PokeGear, Goldenrod and Hoenn path with
no bike, then Mr. Briney, home too early, sailed the player to Dewford. Saved in Dewford.

To regenerate, in a `git archive bcfc96d860` tree built with `make modern` (`touch .histignore` first):

```sh
cp <repo>/test/overworld/lua/XRegionDamageFixtures.lua test/overworld/lua/
test/overworld/mgba-run.sh --timeout 1500 --env PW_XREGION_CASE=damaged test/overworld/lua/XRegionDamageFixtures.lua pokemonworld.gba
```

and copy the first 131072 bytes of `<case-dir>/emulator/Verify1.sav` out (the runner takes raw flash
images, so mGBA's 16-byte RTC trailer is dropped). `XRegionSaveRepair.lua` and
`XRegionSaveRepairVoyage.lua` continue these saves; `test/overworld/TestXRegionSaveRepair.py` checks
the damage in each file and SavePatch's offline repair of it.
