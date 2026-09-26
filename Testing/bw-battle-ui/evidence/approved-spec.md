Feature: adopt Mudskipper's BW battle UI across Pokémon World

## Decision and result
The owner selected **Mudskipper's BW battle UI** after reviewing real donor emulator captures of move selection, all four effectiveness indicators, the move-info popup, the R-button ball shortcut and a Poké Ball throw.

Port that visual direction into Pokémon World: angular BW command/move panels, outlined health boxes and text, ability popups, party-status bars, move details and ball/gimmick controls. Preserve World's gameplay and existing SwSh bag/party/summary interfaces. The implementing agent owns integration and validation; no further UI-direction choice is needed.

This is the implementation specification. The planning work did not modify World's game files. The regional palette proposal (review section 3.2) was separately cancelled and remains cancelled. HGSS battle UI is not selected.

## Pinned sources and known baseline
- Donor: [mudskipper13/pokeemerald, feature/bwBattleUI](https://github.com/mudskipper13/pokeemerald/tree/b798929811ec7d070616c7ef47e46cfc6a7f1501), commit `b798929811ec7d070616c7ef47e46cfc6a7f1501` (May 2026).
- Feature-only comparison: [upstream parent 68a5890c… → pinned BW tip](https://github.com/mudskipper13/pokeemerald/compare/68a5890c8548bc04e92b9cdf188aedc11345fc87...b798929811ec7d070616c7ef47e46cfc6a7f1501). Audit identifies 65 changed files, including 37 graphics assets; use that change set as the port inventory.
- [Author-submitted feature documentation](https://github.com/TeamAquasHideout/Team-Aquas-Asset-Repo/wiki/Feature-Branches#bw-battle-ui) identifies the branch as an original BW demake for expansion 1.15.3+ and notes incomplete expansion-feature coverage.
- World inspected at `45e1bf82ca5c2728910127863b926e627d4f18fc`: expansion 1.16.3 plus untagged 1.16.4 development changes, upstream `82598c4d88c9a141d350061575fe3c6810743d4b`.
- Work from the current World branch when implementing. Selectively adapt feature changes; keep World's engine version, current APIs, save/link formats, region systems and bug fixes. Do not merge the donor campaign or overwrite current battle source files wholesale.

The local review is [here](http://127.0.0.1:8766/#bw). On the planning workstation, native PNGs, a five-second clip, capture script, fixture source and provenance are under `/tmp/pkmn-world-visual-review/bw-capture/` and `/tmp/pkmn-world-bw-preview/`. These scratch locations are supplementary, not prerequisites for another agent: reconstruct the documented fixture below if they are absent. Do not copy the temporary `src/main.c` boot hook or `bw_preview_harness.c` into the shipped game.

## Approved visual and interaction contract
| Surface | Required behavior |
| --- | --- |
| Action panel | Donor BW Fight/Bag/Pokémon/Run layout and cursor, retaining World input/availability rules. |
| Move grid | Type-colored BW cells, full move names, current/max PP and effectiveness symbols together. Preserve four slots, empty/status/disabled/zero-PP states. |
| Effectiveness | Preserve World `B_SHOW_EFFECTIVENESS = SHOW_EFFECTIVENESS_ALWAYS` and `B_SHOW_TYPES = SHOW_TYPES_ALWAYS`; donor SEEN is not the desired setting. Retain × immune, ⊙ super effective, △ resisted, ○ neutral; status moves have no damage-effectiveness symbol. |
| Move information | Existing L button opens category, power, accuracy and description; cancellation restores the exact selected move, cursor and UI resources. |
| Ball shortcut | Existing R tap/release throws when allowed; R+D-pad cycles balls. Cycle/release/cancel behavior, inventory counts, last-ball depletion and restrictions remain correct. |
| Health boxes | BW single/double/Safari layouts, names, level/gender, status, HP and EXP information; retain current numerical HP toggle and gameplay data. |
| Party status / abilities | Donor BW status bars and ability popup presentation with correct timing, cleanup and ownership. |
| Gimmick controls | BW triggers for mechanics already supported/enabled by World; correct state/cancellation and coexistence with L/R controls. This feature does not enable new mechanics. |
| Capture animation | World's existing catch calculation and throw animation rendered in the BW interface. No new catching mechanic or altered odds. |

### Readability requirement
The reviewed donor shows tight spacing between long names and effectiveness symbols. Resolve that as routine implementation work, preserving the selected BW style:
- Budget and measure the move-name area, effectiveness glyph and right-aligned PP separately, with visible separation (aim for four native pixels between name/icon content and PP; at least one clear pixel in the tightest valid case) and no overlap.
- Use the existing font-fit/width APIs and suitable bundled narrow variants within this battle UI. Keep complete move names and meaningful PP; do not silently abbreviate names or remove effectiveness to make them fit.
- Exercise longest supported names, 0/max PP, two-digit PP, variable-type moves and the longest permitted nickname at native 240×160.
- Render dynamic type/effectiveness using World's current battle context, including target selection, abilities, items, current terrain/weather and any already-supported form/gimmick. UI calculation must not consume gameplay RNG or mutate battle state.
- Keep the accepted outlined text and type/status distinctions readable over bright, dark, ice and snow backgrounds. Do not globally replace fonts as part of this port.

## Integration work packages
1. **Inventory and adapt the feature-only diff.** Start with `src/bw_battle_ui.c`, its data/assets, `include/bw_battle_ui.h`, `include/config/bw_battle_ui.h`, then integrate its hooks into current battle interface/controllers, message/text windows, background loading and gimmick handling. Include build/font graphics rules and declarations needed for the exact assets.
2. **Enable the complete selected presentation.** Keep BW TEXTBOX, INPUTBOX, PARTY_SUMMARY, HEALTHBOX, ABILITY_POP_UP and WINDOW_SPRITES components coherent. Do not ship an accidental mix caused by skipped donor hooks. Preserve World configuration values for move effectiveness, move information, ball cycling and move rearrangement.
3. **Handle shared structure changes deliberately.** Donor adds battle fonts 14–16, widens `TextPrinter.fontId` from four bits to a byte and `Subsprite.x/y` from signed bytes to signed halfwords. World currently has the older fields plus its own text-printer lifecycle extensions. Integrate only required changes; retain existing enum IDs, callbacks, linked-printer fields, layout/initialization contracts and all existing fonts. Review all consumers and any generated size/offset symbols. If the wider subsprite range can be avoided by a local donor-coordinate adjustment, that is an agent-owned implementation choice; otherwise validate every affected shared renderer path.
4. **Preserve custom regional battle behavior.** Keep `GetCurrentRegion()` handling in player/controllers/background/message code: Kanto first battle, Oak/Old Man versus Hoenn Wally tutorials, Bills/Lanettes text and custom regional player/back-sprite selection. Retain the six player outfits and supported gender/back-sprite paths.
5. **Preserve World service/battle flows.** Battle Net leader simulation rules (including no-whiteout/no-prize behavior), Frontier state, Lance multi battle, trainer escape behavior, caught-Pokémon storage/party prompts and existing bag/party callbacks must remain correct.
6. **Resource ownership and teardown.** Inventory BG character/tilemap allocations, palette banks and OBJ tile/palette tags for every new component. Donor move cells use BG palettes 10–13; ability popup, cursor and shortcut tags require explicit sharing/lifetime checks. Include the pinned tip's EXP-bar fix that avoids palette indices 12–15. Guard allocation failures before indexing sprites/tiles. Cleanup must run on menu transitions, flee, capture, win/loss, faint/switch, reset/reopen and forced battle exits. Reopening a menu or battle must not leak tiles, palettes, tasks or printers.
7. **Shared nonbattle callers.** Donor also touches egg-hatch and trade presentation and shared ability-popup timing. Preserve those existing World flows and inspect their textbox/palette consumers. Any necessary shared font/sprite change gets matched control captures outside battle.
8. **Attribution.** Add a specific BW battle UI credit to World's existing `CREDITS.md` for Mudskip/Mudskipper (`mudskipper13`), pinned source and any per-asset contributors identified in the feature diff. Retain RHH/pret and existing credits. Preserve asset/source notices; do not replace the whole credits document or invent a blanket license.

### Source-specific adaptation checklist
- Import the new `src/data/bw_battle_ui.h`, `include/constants/bw_battle_ui.h` and `graphics/battle_interface/bw/` assets with the module. Hook current `battle_gfx_sfx_util.c`, `battle_main.c`, `battle_gimmick.c`, Safari and Wally controllers as required. Adapt the Kanto window table separately from the standard table.
- World's effectiveness engine uses `struct DamageContext`, `abilities[battler]` and `holdEffects[battler]`. Donor uses the older `BattleContext` with scalar attacker/defender fields. Build the indicator helper on World's current APIs, keeping `updateFlags = FALSE`, `GetOppositeBattler`, `GetPartnerBattler` and the Silph Scope ghost-concealment rule. Preserve `gParties[trainer]` / `gPartiesCount`; do not reintroduce the donor's player/enemy party memory layout.
- Add `FONT_OUTLINED`, `FONT_OUTLINED_NARROW` and `FONT_BATTLE_UI_ELEMENTS` without renumbering existing IDs 0–13. Donor charmap uses `FONT_OUTLINED_HP_NUMBERS` for the third font while C uses `FONT_BATTLE_UI_ELEMENTS`; normalize or provide an intentional compatibility alias for 0x10. Preserve status glyph escapes F9 19–1E, World's SwSh down-arrow conditionals and its existing printer-lifecycle extensions.
- BG UI palette banks 0–1 and 10–13 must remain isolated from battlefield banks 2–4. Inventory each mode's VRAM usage; donor normal/Z move windows deliberately reuse tiles (first window 0x200, regular following windows 0x2AC/0x2D6/0x300, description 0x32A). Never display mutually overlapping normal/Z layouts at once.
- Donor changes the ordering of healthbox/summary tile tags and introduces cursor/move-info/ability tags. Audit all callers rather than interpreting tags as palette-slot numbers. BW ability popups and L/R trigger sprites share `TAG_ABILITY_POP_UP`; freeing popup resources must not invalidate a live shortcut's palette.
- Donor changes the background-clear tile for `monbg` animations and increases the ability-popup pause. Validate sprite-to-BG/darkening attacks and restoration; scope timing changes to the enabled BW presentation while retaining battle resolution behavior.
- Preserve Bug-Catching Contest scoring and `CB2_EndBugContestBattle` cleanup, recorded battles, Johto leader/champion backgrounds and Kanto champion/intro backgrounds. Maintain World's existing form/gimmick eligibility, including disabled systems; a donor graphics asset does not authorize enabling its mechanic.
- Verify trade/link-end and hatch textbox graphics, tilemaps and text colors as matched sets; these shared consumers must remain readable when the battle textbox changes.
- Credit Mudskip/mudskipper13 for the BW demake code, interface art and outlined fonts, plus RHH/pret and inherited asset notices. The pinned tree has no explicit root or BW-component license; record **no explicit standalone license found**, not an invented MIT/CC license. The author's public feature listing supplies provenance. No author contact was performed or requested.

## Dependencies and coordination
- **#327 battle backgrounds/palettes:** compatible companion feature, not replaced by BW. Keep environment/terrain selection and gameplay mechanics independent from the UI. Integrate in a coordinated order because `battle_bg.c` is shared. Final captures must exercise BW over ice, snow and ordinary outdoor day/night backgrounds; #327's background palette scope must not recolor UI or sprites.
- **#328 Montblanc refresh:** keep the installed SwSh bag, party and summary screens, including direct item actions, registered-item behavior and return callbacks. Coordinate shared fonts/text/resource changes. Final validation uses their landed state when delivered together.
- **#332 / #333 frames and navigation:** battle frames belong to this BW specification; generic SwSh-frame changes must not restyle the battle.
- **Menu font preservation:** the compact-digit proposal was rejected. Scope BW's added fonts to the battle UI and preserve existing menu digits and SHORT/NORMAL bindings outside that scope.
- Regional palette proposal 3.2 is cancelled. Title/logo/box art and hub layout are separate approved/pending work.

## Reproducible fixture and capture matrix
The agent creates deterministic fixtures and drives the emulator. Do not ask the owner for a save file, screenshots, debug-menu input, manual warps or scenario setup.

The reviewed fixture uses a fresh in-memory Route101 wild battle:
- Player: Dragonite level40, Inner Focus, no held item, Thunderbolt / Surf / Flamethrower / Dragon Claw.
- Opponent: Geodude level15, Sturdy, no held item, Defense Curl; mark seen for matching the donor reference, and also test unseen under World's ALWAYS setting.
- Supply Poké, Great, Ultra and Master Balls to test-only bag data. Ordinary catch mechanics stay active.
- Expected type categories against Geodude: Thunderbolt immune, Surf 4×, Flamethrower ½×, Dragon Claw 1×. The selected UI displays category symbols, not numeric multipliers.
- Pin RTC/seed and camera/state for before/after captures. Advance intro text using normal input. Resolve emulator addresses from the exact current ELF; the donor has multiple static functions named `HandleInputChooseAction`, so a name-only global symbol lookup is unsafe.

Required agent-owned evidence:
| Area | Cases |
| --- | --- |
| Moves/readability | Four effectiveness categories together; status/empty/disabled/zero-PP slots; long names and nicknames; L info open/close; dynamic type changes; seen/unseen; normal and forced target selection. |
| Single battle | Wild and trainer; intro, turn action, damage/HP drain, status icons, ability popup, switch/faint, EXP/level-up, win/loss/flee and return to field. |
| Doubles/multi | Four battlers, player/opponent HP boxes, two opponents, partner target selection, cancel from second action, forced replacement and Lance multi-battle flow. |
| Catching | R shortcut and bag throw, ball cycling/cancel/depletion, throw/absorption/shake/success/failure, full party/storage prompt and unavailable shortcut in trainer/Frontier/no-bag contexts. |
| Safari/tutorials | Safari ball counter 30→29; Kanto Old Man and first-battle flows; Hoenn Wally catching tutorial. Check the correct trainer/player name and control mode. |
| Menu transitions | Battle → SwSh bag/party/summary → battle; use/cancel/reopen; faint replacement; postbattle move learning/evolution as applicable. |
| Palettes/resources | Bright/dark/ice/snow backgrounds, terrain change and restoration, long ability messages, all player outfits; resource-pressure fixture; 30 repeated battle/menu cycles with stable live resource counts. |
| Shared controls | Trade scene and egg hatching; dialogue/default frame; bag/party/summary text; overworld sprite/subsprite composition following any shared renderer changes. |
| Network/facility/mechanics | Local automated link-battle pair, Frontier entry/resume, Battle Net simulation, existing enabled gimmick triggers and return paths. Agent prepares both emulator instances when needed. |

## Checks and definition of done
- Capture and record baseline first; build current development and release ROMs after the port and regenerate test symbols from each exact build.
- Run `make validate` and the relevant battle engine tests through the current repository's `make check TESTS=...` selection mechanism. Include ball throwing, type effectiveness/dynamic-type scenarios, terrain changes, Transform/Illusion and supported gimmicks when the changed hooks touch them. Confirm test selection actually executes cases and record names/results.
- Run tracked Lua suites through `Testing/mgba-run.sh`: `ExpansionHealthboxes`, `CatchTutorial`, `LanceMultiBattle`, `FrontierMidSave`, `BnetTerminal1F`, `LevelUpSummary`, `VerifyBagLayout`, `VerifyPCScreen`, `PromptSafetyEvIv`, `DayNightTint`, plus `DaycareFullPartyEgg` and relevant shared-renderer controls when affected. `DaycareFullPartyEgg` checks egg receipt, not hatching; create an actual hatch-sequence fixture separately. Add trade, recorded-battle and Bug-Catching Contest fixtures where tracked suites do not cover them. Inspect what each suite actually proves; supplement missing cases with deterministic automation.
- Add a focused BW UI regression/capture suite that proves correct battle states, target/cursor actions, ball-count changes, restoration and resource lifetimes. Do not count screenshots alone as mechanical assertions, or logic-only passes as visual approval.
- Existing tests tied to classic pixel coordinates may need deliberate BW expectations; retain semantic coverage instead of deleting assertions or bypassing whole scenarios.
- Provide matched native screenshots and short motion clips for HP/EXP, ability popups, move-info/menu return and ball throwing. Include checksums/commit IDs, actual commands and all limitations in one evidence index.
- Fresh normal boot retains the approved title/start behavior. No test harness, debug autostart, seeded test party or fixture items ship in the release.
- No new save migration, gameplay/roster change, engine downgrade, lost local customization, hidden unsupported battle flow, or unrelated workspace edit.
- The agent fixes discovered integration regressions before calling this ready. Unsupported donor paths are implementation work; do not disable existing World features to avoid porting them.

## Agent-owned delivery and final owner playtest
The owner has approved this feature spec and wants minimal involvement. The implementing agent owns the remaining engineering investigation, asset preparation, build setup, fixtures, automated checks, emulator operation, regression diagnosis and visual evidence.

- Work in an isolated branch/worktree and preserve unrelated workspace edits. Read the current repository instructions and this issue's dependencies before starting; the source baseline above is evidence, not permission to overwrite newer work.
- Resolve routine technical choices autonomously within the stated scope. Inspect every graphics/palette/window caller affected by a shared change. Never substitute an untested assertion for runtime evidence.
- Use Testing/mgba/README.md and tracked Testing/lua suites with the current symbol-generation workflow. Create reproducible test saves/fixtures as needed; do not request the owner's save, screenshots, manual warps, debug-menu operation or test results to complete engineering validation.
- Build development and release ROMs. Run the checks appropriate to the changed surfaces, investigate failures and repeat only when fixes justify it.
- Generate matched native-resolution before/after screenshots and short recordings for animation, palette transitions or return flows. Publish a concise evidence index with exact source commits, commands, results and any remaining limitation.
- Provide one ready-to-play release build using the project's existing delivery convention, its commit identifier/checksum, and a short final-playtest route or prepared test save. Owner playtesting must fit approximately 5–10 minutes and involve normal gameplay controls.
- Owner sign-off is final visual/gameplay judgment. It is not a substitute for the agent's regression tests or a request for the owner to configure the toolchain.
- If a prerequisite cannot be met, document the exact blocker and continue independent work. Do not claim readiness or ask the owner to perform routine technical work. Seek owner input only for an unresolved product/art choice that cannot be resolved from the approved direction.




## Combined owner handoff
When this feature ships with other approved visual changes, combine them into one concise evidence pack and one approximately 5–10 minute final owner playtest. Do not assign a separate manual test matrix for every issue. The agent runs the complete per-feature regression/capture matrix, prepares the build and any fixtures, and selects a short representative route. The owner judges the finished appearance and normal gameplay only.

Planning estimate: approximately 7–12 engineering days including adaptation, shared-renderer checks and the full capture matrix. This is a scope estimate, not a promised delivery date. Visual impact: high.
