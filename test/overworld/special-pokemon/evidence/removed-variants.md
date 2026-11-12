# Eight-variant build scope

Owner review on 2026-11-12 removed Explorer Treecko and Swim Ring Mudkip from this unmerged build. Their species declarations, species data, forms entries, catalog rows, source NPCs, Fortree trail quest, scripts, and eight exclusive flags are removed. The other eight species IDs and 24 flags retain their prior numeric values. Existing base-species IDs and unrelated flags are unchanged.

FortreeCity and DewfordTown maps and Fortree scripts return to their pre-feature content; base Treecko/Mudkip metadata no longer has the custom Forms tables. Checklist totals derive from `SPECIAL_POKEMON_COUNT` and show eight entries, with five icons on the first page and three on the second.

Updated test fixtures cover eight metadata/acquisition entries, two catch sources, three tasks and 15 source placements. The visual fixture still covers five female samples using shared art. Expected mechanics masks are `00FF/00FF/03FF/003F/00FF`; the independent storage/recovery case still contains ten assertions. Capture ownership mask is `0082` (Surfboard and Pirate).

Source and flag checks pass; `python3 test/validate-host.py` passed 23/23 in 12.1 seconds. Full log: `/tmp/pkmn-386/removed-variants-host.log`. `git diff --check` passed.

No production build or emulator checks were run for this removal by the removal worker. Art generation and the next build/runtime validation belong to the parent task. Prior ten-variant runtime reports are historical and do not validate this eight-variant build.
