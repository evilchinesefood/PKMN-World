# Ambient placement checks

`ValidateOwMonPlacements.py` now checks whether an outdoor, scriptless,
non-cutscene Pokemon has an approach tile connected to a warp or map edge.
The model includes collision, elevation, Surf and directional ledge jumps.
It deliberately ignores NPC/story gates and does not simulate ice, Strength,
Rock Climb, holes, whirlpools, or complex stairs. It is a content review aid,
not proof that a player can complete a map.

`OwMonReachabilityBaseline.json` pins unresolved counts per map. Both increases
and decreases fail: repair increases, and lower the baseline after reviewing
an improvement. A fresh map defaults to zero. The baseline is not a list of
confirmed gameplay defects; caves and disconnected map sections need emulator
inspection before moving their objects.

For #288, placement changes are limited to towns/routes with at least 60%
walk coverage and Burned Tower. Moves are within ten Manhattan tiles and
avoid occupied/event tiles, warp approaches and one-tile corridors. Original
land/water terrain is preserved. Unresolved cases remain in the baseline.

For #291, an explicit habitat policy covers aquatic scenery such as fish,
Tentacool, Mantine, and Corsola. It does not treat every Water type as
water-only: Seel and Dewgong can rest on shore. Script-driven actors such as
the Route 41 Tentacruel barrier are excluded from scenery relocation. On
this branch, 25 ambient water-only placements were on dry tiles; all are
now on water. One Corsola in Whirl Islands B1F needs a 13-tile move to reach
suitable water. The fork's 42-placement count is not this branch's census.

For #292, the gate no longer exits north into the isolated strip. The old
strip's three return warps remain, pointed at the gate's surviving south
exit, so an existing save on the strip can still leave.

Run:

```
python3 Testing/ValidateOwMonPlacements.py
python3 Testing/TestOwMonReachability.py
```

The placement validator already runs in `make validate`, CI and pre-push.
