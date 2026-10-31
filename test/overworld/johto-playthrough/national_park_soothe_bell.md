# National Park Soothe Bell passage

[Issue #359](https://github.com/evilchinesefood/PKMN-World/issues/359) reports two
ambient Pokémon blocking the passage to the Soothe Bell after the Cut tree.
Nidoran♀ and Weedle have no interaction script or wild-encounter trainer type.

The fix moves Nidoran♀ from `(32,4)` to `(28,8)` and Weedle from `(33,5)` to
`(30,10)`. Both retain their horizontal movement and range of two tiles. Their
patrols occupy open grass instead of the narrow item passage.

## Run the regression

Build the ROM with `make modern -j8`, then run this command from the repository root.

```sh
python3 test/overworld/johto-playthrough/run.py --suite national_park_soothe_bell.lua
```

The fixture starts a disposable save, sets Johto and its first badge, gives a
level-100 Chikorita with Cut through the debug menu, and lowers its met level for
obedience. It enters National Park through a debug warp. The tree interaction,
Cut, corridor movement, item collection, and return walk use controller input.
The test checks exactly one Soothe Bell in the Bag and the item's hide flag.

## Baseline evidence

The parent ROM at `a0557b387c30b2b943f159e85bf3777200ea9c13` has MD5
`CBF96BB4C1391D2C3B1FE86B8F16AFDA`. After Cut, the player reaches `(32,4)`.
Ten Right attempts and ten Down attempts fail. Pressing A starts no battle and
leaves player control available. The item remains uncollected.

- [Controller log](evidence/359/before.log).
- [Failure sentinel](evidence/359/before.FAIL).
- [Blocked passage screenshot](evidence/359/before-blocked.png).

The baseline exits with code 1 and a fresh `.FAIL` sentinel. Six of ten checks
pass. The shared logger prints `PASS` in its count line even when assertions
fail, so the exit code and sentinel determine the result.

## Fixed runtime evidence

The fixed ROM was built from `9c67c06120`, the regression-test commit, with only
the two object coordinate changes in the working tree. Its MD5 is
`7BD8106B8874A532CC2189C0FEDD8397`.

The unchanged regression exits with code 0 and a fresh `.PASS` sentinel. All ten
checks pass. The player cuts the tree, reaches `(39,14)`, collects exactly one
Soothe Bell, sets the item hide flag, and walks back through the passage.

- [Controller log](evidence/359/after.log).
- [Success sentinel](evidence/359/after.PASS).
- [Item collected screenshot](evidence/359/after-collected.png).

An earlier pathfinding-only attempt was discarded because an unspawned light
object confused its route search. The retained baseline and fixed runs both use
the same literal controller route after Cut.
