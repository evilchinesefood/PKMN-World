# Pokémon World — Changelog

All notable player-facing changes. For the full feature reference see
[FEATURES.md](FEATURES.md); for credits see [CREDITS.md](CREDITS.md).

## v1.3.1 — 2026-07-11

Ten-agent deep review of the whole codebase; every confirmed finding fixed.

### Progression fixes

- **Blackthorn soft-lock (critical)**: becoming Hoenn or Kanto Champion before
  beating Clair no longer locks you out of the Rising Badge — her post-league
  dialogue now keys on the JOHTO championship only.
- **Johto first-clear as an outside champion**: clearing the Johto league after
  already being another region's Champion now correctly runs the first-clear
  sequence (post-game Johto events, S.S. AQUA state, Indigo guards) instead of
  the repeat-clear one.
- **Gym TM can no longer be lost**: if your bag was full when a leader first
  awarded their TM, the re-offer now happens before the champion rematch gate
  in all eight Hoenn gyms (the other regions were already correct).
- **Norman's HARD rematch is permanent**: the vanilla match-call rematch no
  longer permanently replaces his champion rematch offer.

### Fixes

- **Egg-only party**: trainers no longer start a battle when your party is only
  an egg (previously possible after a region switch plus a gift egg).
- **Flight shadow on bridges**: the Sky Charm ground shadow now follows the
  terrain under you instead of vanishing beneath bridges.
- **Old champion saves**: continuing a pre-rematch champion save now applies
  HARD difficulty immediately instead of after the first hub trip.
- Blackthorn's gym guide now finishes his pep talk ("You got this!"), and five
  rematch lines were shortened to fit the message window.

## v1.3.0 — 2026-07-11

### Gym Leader rematches (Feature C)

- **All 24 gym leaders offer unlimited rematches once you're that region's
  Champion** — talk to them in their gym. Every leader fields a new HARD team
  (Lv 58–65, ace ~65, held items, competitive movesets): Steelix Brock,
  Light-Ball Raichu Surge, Scizor Bugsy, Mamoswine Pryce, Kingdra Clair and
  Juan, Slaking Norman, a Solrock+Lunatone double core for Tate & Liza, and
  more.
- Difficulty now follows the region you're in: champion regions fight HARD
  rematch teams, regions you haven't cleared stay normal — so a Hoenn
  champion starting Kanto still faces the classic first-run gyms.

### Fixes

- **Fishing actually works now**: the hidden half-second reaction test after
  "Oh! A bite!" is gone — the bite waits for your A-press, and pressing A
  early during the dots no longer scares it away. One bite, one press, one
  battle.
- **Sky Charm flight**: facing up, you now ride visibly on your Pokémon's
  back; in every other direction the Pokémon correctly overlaps you. A
  ground shadow tracks beneath you for the whole flight.
- **Trainer Card**: region label repositioned next to "BADGES".
- **Autosave** now waits at least 10 minutes between saves.

## v1.2.0 — 2026-07-11

### Kanto polish

- **Map previews are back**: entering Kanto dungeons (Mt. Moon, Viridian
  Forest, Rock Tunnel…) shows FireRed's full-screen area preview — long on
  your first visit, quick on returns. Johto and Hoenn are unaffected, and the
  name popup no longer appears twice.
- **FireRed canon restored**: Professor Oak's name suggestions are FireRed's
  (RED, FIRE…), and Kanto's in-game trades use the FireRed offers (MS. NIDO
  the Nidoran♀, NINA the Nidorina, and the Golduck-for-Lickitung request).

### Slimming (ROM 90.9% → 67.0% full)

- **265 Pokémon families from Gen 4–9 that never appear anywhere in the three
  campaigns are disabled** (~6.75 MiB). Nothing you can catch, evolve, or
  fight is affected — every Gen 1–3 line and all their evolutions remain. The
  National Dex diploma and the hub's completion reward now count only
  obtainable species.
- Gigantamax and Terastal form data removed (nothing here can trigger them);
  the **Mega Evolution system stays** for possible future endgame content.
- **Trainer Tower is closed for renovations** — the Sevii facility was never
  functional in this merge; the Battle Frontier is the endgame facility.
- Engine slimming: GameCube/e-Reader/Berry-fix link-era payloads removed,
  empty trainer-slide tables made sparse, Japanese glyph sets dropped
  (English-only build).

## v1.1.3 — 2026-07-11

### Fixes

- The **Magnet Train** departure now shows an actual magnet train gliding down
  the track (a station clerk had been standing in for the train).
- The **Goldenrod haircut brothers** now offer haircuts again each new day.
- Challenging a trainer with an **empty party** (right after a region switch)
  now gets a polite refusal instead of a broken battle.
- Mt. Silver mountainside Pokémon patrol their full intended ranges.
- Minor gym text cleanups (Olivine, Violet).

## v1.1.2 — 2026-07-10

### Fixes

- **Fishing** reworked to a single reaction — one bite, one prompt.
- The rider now sits properly on the **mount's back** instead of floating
  alongside.
- **Safari Zone** exit and ¥500-continue fixes across all regions.
- **Trainer Card** badge-page label corrected; pages flip with UP/DOWN (or L/R).
- **Chuck** now correctly awards the **Storm Badge**.
- Each region's **Elite Four** fields its own per-region difficulty.
- **Legendary encounters** guard against duplicates, and the **Celebi** event
  can be retried.
- **Gift Pokémon** are no longer lost when your party is full.
- **Johto League** Fly and respawn locations corrected.
- Assorted text fixes (ellipses, stray spaces, dashes) across Johto and the hub.

## v1.1.1 — 2026-07-10

### Fixes

- **Fly** now shows the Pokémon you picked (Sky Charm and HM), not Flygon, and
  the landing no longer plays a second swoop.
- Leaving the **Kanto Safari Zone** returns you to Fuchsia City instead of
  Hoenn's Route 121 entrance.

### Quality of life

- Running out of **Safari Balls** now offers the same ¥500 continue as running
  out of steps (refills 30 balls + steps); declining exits normally.
- The **Pokédex** main page now shows your current region's SEEN/CAUGHT plus a
  TOTAL caught across all regions (replaces the old HOENN/NATIONAL rows).
- The **Trainer Card** also cycles regions with UP/DOWN (L/R still works).
- **Autosave** fires at most every ~2 minutes (was ~1).

## v1.1 — 2026-07-10

### Endgame

- **World Championship** — once you're Champion of all three regions, a registrar
  in the Battle Dome lobby offers a 15-trainer bracket of cross-region champions
  (Red, Blue, Lance, Steven, Wallace, the four Elite Fours, and Sabrina/Clair),
  with Red waiting in the final. Rewards a permanent title and a Gold Bottle Cap,
  and is rematchable afterward.
- The **Battle Frontier** is now gated behind clearing at least one region's
  league.
- **Hoenn's Elite Four and Champion rematch** now fields genuinely upgraded HARD
  teams (Lv 62–68, competitive movesets) once you're Champion — your first clear
  still faces the normal gauntlet.

### Quality of life

- **Fly** and the **Sky Charm** now show your actual flying Pokémon carrying you,
  instead of a generic bird or a fixed Flygon. The Sky Charm mount now renders
  above trees and walls.
- **CATCH RATE** gains a 0.5× tier, matching EXP RATE (now 0.5×/1×/1.5×/2×).
- The **Pokédex** adds a CAUGHT counter (total captures) below SEEN/OWN.
- All **evolution items** (Steel Coat, etc.) are now sold in the department
  stores.
- A new **post-game Dex-reward NPC** in the World Transit hub: 150 caught → PP
  Max, 300 → Master Ball, full National Dex → 10 Rare Candies + a diploma.

### Fixes

- Game Corner coin buying now fills the case to max instead of blocking when
  it's nearly full, and a larger 3rd coin-buy tier was added.
- Celadon's prize-corner Pokémon purchase is fixed (was showing "WEEZING" and
  not giving the Pokémon).

### Engine

- Synced 20 upstream rh-hideout battle/AI fixes.

## v1.0-beta — 2026-07-05

### The Game

**Pokémon World** merges **Kanto**, **Johto**, and **Hoenn** into a single Game
Boy Advance game, built on pokeemerald-expansion. Each region is a complete,
self-contained adventure — its own story, 8 gyms and badges, Elite Four, and
Champion — chosen from a central **World Transit hub**. Your bag, PC boxes, and
Pokédex are shared across all three, so the Pokémon you raise travel with you
between worlds.

### Regions & Campaigns

- **Kanto** — the full FireRed campaign: every trainer fights their authentic
  FireRed team, real gym leader / Elite Four / **Champion Blue** rosters, rival
  **Blue**, and the 8-badge league gate.
- **Johto** — fully ported from *Heart & Soul*: ~245 maps, 231 real trainer
  parties, its own wild encounters, town map, Fly and heal locations, rival
  **Silver**, and the Johto League (Will, Koga, Bruno, Karen → **Champion
  Lance**). Post-game: **Red at Mt. Silver**, the roaming beasts, the Celebi
  GS Ball chain, the Ruins of Alph puzzles, the Bug-Catching Contest, and the
  Ho-Oh / Lugia events.
- **Hoenn** — the native Emerald campaign, with the **Battle Frontier** as the
  shared post-game battle facility for all three regions (reachable straight
  from the hub).
- Each region's **starter trio is catchable in the wild** on its first route
  (Route 1, Route 29, Route 101) — the two starters you didn't pick aren't
  lost.

### World Systems

- **World Transit hub** — new games open with a unified intro (gender, name,
  outfit), then land in a terminal with staffed departure gates for Kanto,
  Johto, Hoenn, and the Battle Frontier, plus a nurse, a PC, a mart with
  department vendors, and a world-tour board tracking all 24 badges.
- **Region switching** — your first visit to a region plays a short "Mom moves
  into a new house" arrival and a choice of that region's three starters.
  Switching regions boxes your party to the shared PC (mail is moved to the PC
  mailbox — nothing is lost). You return to the hub through each region's own
  access point — the Goldenrod Magnet Train, Vermilion harbor, or Slateport
  harbor — and once you're champion of two regions, every Pokémon Center 2F
  gains a World Transit warp pad.
- **Shared progress** — one bag, one PC, one Pokédex, one wallet. Story,
  badges, and trainer defeats are tracked per region; obedience and HM field
  moves follow your **current** region's badges.
- **Multi-page Trainer Card** — L/R flips between the Hoenn, Kanto, and Johto
  badge pages.
- **Character customization** — play as **Brendan or May** everywhere, with a
  six-outfit color picker (live preview in the intro) that applies globally:
  overworld, battle, and trainer card.

### Major Features

- **Follower Pokémon** — HGSS-style walking followers, plus a "Follow" chooser
  in the party menu so any party member (not just the lead) can walk with you.
- **Overworld flight** — the **Sky Charm** key item toggles free flight over
  the outdoors on a Flygon mount. Granted at the hub after your first badge in
  any region; flying within a region requires that region's Fly badge.
- **Graphical start menu** — a sprite-icon Start menu with entries you can
  rearrange, day/night aware, including a Quests entry.
- **DexNav** — granted with each region's Pokédex; the hidden-Pokémon detector
  unlocks with your first championship. Hidden encounters are authored for
  every land map, skewing rarer and slightly higher-level than the local
  grass.
- **VS Seeker rematches in Kanto** — the VS Seeker now offers rematches from
  85 trainer groups across Kanto, with teams that escalate as you earn badges.
  Hoenn keeps Match Call, and its rematch offers now survive moving between
  areas.
- **Dynamic surf** — you surf on your own Pokémon: the first party member that
  knows Surf appears as your mount.
- **Autosave** — an optional autosave (off by default) that quietly saves as
  you move between areas.
- **Hard Mode & battle options** — Hard Mode (Set-style battles, no bag items
  against trainers, badge-based level caps), an EXP multiplier (0.5×–2×), a
  catch-rate multiplier (1×–2×), and a Run shortcut for fleeing wild battles —
  all in the Options menu, which now scrolls to fit.
- **HGSS-style Pokédex** — the detailed HGSS Pokédex interface.
- **Sword/Shield interface suite** — SwSh-styled party menu, summary screen,
  PC storage, bag, message and name boxes, and map-name pop-ups.
- **Quests** — a mission-log Quest menu on the Start menu.
- **Key-item wheel** — ORAS-style SELECT registration for up to four key
  items, one per D-Pad direction.

### Quality of Life

- Battle **type and effectiveness icons** are always shown.
- **Nicknames** — rename Pokémon straight from the party menu or the summary
  screen (outsider Pokémon follow the usual Name Rater rules).
- **PokéVial** — a refillable full-party heal, given as a welcome gift by the
  hub's Charm Curator.
- **Hub distribution** — the Harbor Master hands out the event tickets (Eon
  Ticket, Old Sea Map, Mystic Ticket) as you win championships and opens their
  ferries; the Charm Curator hands out the charms at badge milestones; the hub
  mart stocks a free Town Map.
- The **Wailmer Pail** is available at the Goldenrod flower shop, so Johto
  berry growing can't dead-end.
- **Chansey attendants** beside the nurse in every Pokémon Center, in all
  regions.
- **Safari Zone** — pay ₽500 to keep going when your Safari time runs out.
- **Auto-Run toggle**, reusable TMs, chain fishing, IV/EV pages on the summary
  screen, move relearners (including TM moves), item descriptions on pickup,
  and visible overworld encounters alongside normal grass encounters.
- The wall clock is set **once, globally** — no re-setting it in each region's
  bedroom.

### Fixes

- **Kanto trainer parties** — every trainer in Kanto now fights their real
  FireRed team, with Kanto's trainer progress tracked independently of the
  other regions.
- **Magnet Train** — the Pass is now obtainable (from the station president
  after the Radio Tower incident), so the train actually runs.
- **Key items no longer duplicate** — you can't collect a second Exp. Share or
  HM across regions; the Cianwood double-Fly and the Mystery Egg / Devon
  Letter mix-up are fixed; and formerly placeholder items (Secret Potion,
  Silver Wing, Rainbow Wing) are now real items.
- **PC** — closing the boxes after opening them from the party menu returns
  you to the party menu; the stuck PC message is gone.
- **Textbox alignment sweep** — message windows across the bag, shops, party
  menu, battle tutorial, and more no longer clip against the right edge of the
  Sword/Shield message frame.
- The **Aurora Ticket** event now correctly opens its ferry (fixed
  retroactively for older saves).
- Lavender Town's Pokémon Center upstairs now uses the correct floor layout.
- The summary screen's sheen meter shows empty at zero sheen instead of a
  phantom sparkle.
- Declining "Retire" at the Battle Pyramid now reopens the menu properly.

### Known notes

- The hidden-Pokémon **detector** activates only after your **first
  championship**, and hidden Pokémon never carry held items.
- **VS Seeker** rematch offers don't survive saving and quitting — recharge
  the Seeker after reloading.
- **Saving is blocked while flying** (land first); autosave also skips while
  airborne.
- In Ghost encounters without the Silph Scope, the effectiveness indicator
  stays hidden — that's intended.
- The overworld **debug menu ships enabled** by design in this build.
