# Regional travel save compatibility

The feature writes save format 11 and continues to load formats 7 through 10 through the existing migration ladder. Formats older than 7 remain unsupported. Older game builds reject a format 11 save; preserve an original save backup before saving in this build if rollback is needed. There is no downgrade conversion.

`RegionalTravelSave` is appended after the existing Johto trainer flags in `RegionSave`. Earlier fields retain their offsets. The regional checksum reader selects the pre-feature width for saves below version 11, then migration initializes the new data. The bank contains three ordered reference lists, three explicit Center IDs, and the next individual-ID counter. No historical team or visit is inferred from the current party or recovery point.

Individual IDs use 20 previously unused encrypted Pokémon bits exposed through `MON_DATA_REGIONAL_ID`. `BoxPokemon` remains 80 bytes. Migration clears those bits in the saved player party, all PC boxes, the ordinary and Route 5 daycares, and fusion storage. This occurs before the live player party is loaded. The normal setters update checksums, including when formerly unused bits contain nonzero data.

IDs are assigned when accepted regional departure first requires them. Allocation does not reuse any live or remembered identity and refuses rather than wrapping. Ordinary movement and evolution preserve an identity; hatching preserves the egg's identity, the extra Shedinja clears its copied identity, and incoming external trades and mystery-event Pokémon clear foreign identities. Ambiguous matches are unavailable rather than resolved by storage order.

The migration fixtures and assertions live in `test/save.c`, `test/overworld/TestRegionalTravelMigration.py`, and `test/overworld/lua/RegionalTravelMigration.lua`. The committed v10 fixtures include ordinary and deliberately nonzero legacy padding. Their generation provenance is recorded in `test/overworld/lua/fixtures/v10regional.md`. Runtime verification remains distinct from host fixture inspection; see the acceptance evidence for the executed commands and results.
