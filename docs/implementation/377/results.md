# Final result excerpts

The full commands and limitations are in [verification](verification.md).

## final-check.log

```text
[02] Rain multiplies the power of Water-type moves by 1.5x: PASS
[02] Strong winds prevent other weather abilities: PASS

- Tests KNOWN_FAILING:   14
- Tests TO_DO:           594
- Tests EXPECT_FAILING:  8
- Tests PASSED:          5119
- Tests TOTAL:           5735

```

## final-sweep.log

```text
CatchTutorial            rc=0   VERDICT CatchTutorial: 15/15 PASS
DayNightTint             rc=0   VERDICT DayNightTint: 32/32 PASS
RegionalTravelMigration  rc=0   VERDICT RegionalTravelMigration: 10/10 PASS
VerifyV7Migrate          rc=0   VERDICT VerifyV7Migrate: 14/14 PASS
MigrateFixtures          rc=0   VERDICT MigrateFixtures: 7/7 PASS
VerifyMapRenumber        rc=0   VERDICT VerifyMapRenumber: 4/4 PASS
VerifyOwnerSave          OPTIONAL - no pokemonworld.sav on this machine, not counted

--- sentinel audit (a .PASS only counts if this sweep wrote it, against THIS rom) ---

green 56 / 56 expected
SWEEP OK - every expected suite produced a fresh PASS stamped rom=30B28AF582B8B400855381A27E3C79FA
```

## feature-travel-runtime-expanded-1.log

```text
  [PASS] actual S.S. Tidal voyage uses normal Frontier dock -- 26/4 (19,67)
  [PASS] accepted S.S. Tidal boarding captures changed Hoenn party
  [PASS] S.S. Tidal keeps Hoenn campaign ownership
  shot RegionalTravel_152_tidal_neutral_departure_confirm
  [PASS] Hub Pass from neutral Frontier returns normally
  [PASS] neutral return cannot replace S.S. Tidal departure memory
  [PASS] S.S. Tidal and direct harbor entry
VERDICT RegionalTravel: 221/221 PASS
---
exit code: 0
```

## final-save-layout-probe.log

```text
probe: 73/73 match the build
```

## final-offline-migration.log

```text
.....
----------------------------------------------------------------------
Ran 5 tests in 0.061s

OK
```
