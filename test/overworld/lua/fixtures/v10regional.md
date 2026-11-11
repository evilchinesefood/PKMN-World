# Version 10 regional travel migration fixtures

`v10regional.srm` is a raw 128 KiB save made by baseline commit `35bf05083e`.
The default `make modern` ROM had MD5 `8885ebc29da759d11578660fe8aa3688`.
It loaded the tracked fresh-game `v7.srm`, created the debug Wobbuffet party through the debug menu, and saved through the normal start-menu Save action.
The player remains in Oldale's Center at tile 7,4. No personal save supplied these fixtures.

`v10regionaldirty.srm` changes only the first party Pokemon's twenty previously unused encrypted bits and the newly allocated regional-travel tail.
The Pokemon checksum is valid. All twenty identity bits are one. Every byte of the future 168-byte bank is 0xA5.
Sector checksums and the version 10 regional checksum remain valid.

Run `python3 test/overworld/MakeRegionalTravelFixture.py --check` to reproduce and validate the dirty fixture against its clean source.
Run `python3 test/overworld/TestRegionalTravelMigration.py` to verify preservation, all persisted owners, all 24 encrypted substructure orders, repeat migration, and damaged-checksum refusal.

The game must migrate both fixtures to version 11 without inventing a remembered team or Center visit.
The dirty fixture's Pokemon must equal the clean fixture's Pokemon after migration.
Continue inside the Center must leave checkpoint history empty until an actual subsequent entry.
