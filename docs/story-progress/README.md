# Story Progress

Open **Start → Story** immediately after normal menu access becomes available.
The graphical menu uses the book icon; the classic menu shows Story in its
action list. Story also works in the hub, Safari Zone, Bug-Catching Contest and
single-player Frontier menus. The disabled legacy quest framework stays off.

The overview shows all three campaigns, their status, badge count and next
action. Up/Down selects a region; A opens details. The initial selection follows
the active campaign, including inside World Transit. A fresh hub save with no
active campaign selects Kanto without starting it.

In details, Left/Right or L/R pages through the chapter/action, destination and
prerequisite, and recap/progress. Up/Down reviews another region. B returns to
the overview, then the original Start menu. Press A on any detail page to choose
**Show destination on map**. Optional detail pages open the optional objective
instead of the main objective. A Champion region retains **Main
story complete** even if an optional chain remains unfinished. The recap is
the latest established milestone derived from the current state, not an
invented chronological activity log.

## Show an objective destination

The map opens on the objective's regional area, including the correct Sevii
island group, regardless of your current campaign. The fixed cursor marks the
area. The player icon appears only when your actual location belongs on that map.
World Transit never displays a player icon on a regional map.

Press A to switch between the map and its location details. The details retain
building, floor, and NPC directions. Press B from either view to return to the
same Story region and detail page. The map cannot Fly or travel. A marker does
not open a blocked route; follow the Story prerequisite text.

Objectives without one meaningful location show their location text and a short
explanation. These include World Transit, free exploration, multiple outstanding
requirements, prerequisites that must finish first, and unknown destinations.
No placeholder pin appears. Only current objectives and already-started optional
chains are available.

## Add a destination to an objective

Keep the destination in the existing `STORY_OBJECTIVE` declaration. Use
`STORY_PIN(SECTION)` for a concrete section present on a regional map. Use the
visible parent area for an indoor objective, and keep the building or floor in
its `where` text. The renderer derives the region and Sevii submap from the
section, so no second region field needs maintenance.

Use `STORY_NO_PIN(HUB)`, `STORY_NO_PIN(FREE_ROAM)`,
`STORY_NO_PIN(MULTIPLE)`, `STORY_NO_PIN(WAITING)`, or
`STORY_NO_PIN(DYNAMIC)` when that explanation matches the current next action.
Do not pin a later step in the chain. The existing resolver selects the current
objective; destination metadata does not add progression rules or saved state.

Run `python3 test/overworld/story-progress/run.py` after adding an objective.
The test requires each authored ID to be reached, every pin to belong to exactly
one actual map layout, and each exemption to have a valid reason and no section.
Use the native fixture below to inspect new location text and markers.

## Coverage and boundaries

There are 164 authored objectives: 46 Kanto, 64 Johto, 51 Hoenn, plus three
not-started entries. These cover each authored main campaign from its opening
through its regional Champion flag, including deliveries, villain scenes,
field-move prerequisites, remaining badges and actual League entrance gates.

Optional pages appear for an already-started Lostelle/Celio errand, Kurt's
GS Ball/Celebi chain, or Wattson's New Mauville request. Completed tracked
chains disappear from the optional pages. This is deliberately a small set,
not a catalog of undiscovered content. Returning to a completed campaign also
offers a source-backed travel/Frontier lead. There are no automatic popups,
timestamps, networking, activity history or new save fields.

The resolver reads absolute regional flags/vars, regional badges/Champion flags
and existing intro bits. Shared inventory is consulted only for a relevant
outstanding prerequisite under local scene evidence. It never establishes
another region's completion. Older supported saves can derive guidance from
their existing progress; no old conversation has to be replayed to create a
new tracking record. Later explicit scene evidence takes precedence over stale
earlier data where the scripts establish that relationship.

For the exact script references, objective transitions, retries, nonlinear
priorities and unusual-state limits, see [Kanto](kanto.md), [Johto](johto.md)
and [Hoenn](hoenn.md). Reminders describe authored state; they do not repair
missing rewards or reconstruct information never persisted by a script.

## Verification

`python3 test/overworld/story-progress/run.py` compiles the production resolver
with host save-bank accessors. Every authored objective must actually be reached
by a fixture. Cases include adjacent transitions, scene/receipt overlaps,
bag-full retries, prerequisite handling, regional isolation, started/Champion
states and save purity. Destination checks read the production map layout arrays and
validate main and optional objective records. It is part of `make validate`, CI and the pre-push gate.
On macOS it pairs the selected Xcode compiler with that Xcode's SDK; `CC` and
`SDKROOT` overrides remain available.

`test/overworld/lua/StoryProgress.lua` drives the production Start menu through
Kanto → Johto → Hoenn → hub → Kanto, opens every region without travelling,
checks active defaults/state/heap restoration, saves, reboots and Continues.
It is included in `test/overworld/run-all.sh`. Existing save tests select the
Save action by ID instead of relying on its position next to the new Story icon.
The Frontier save test also waits for the actual flash transaction completion
before rebooting; a party-size check alone could stop during the write.
`VerifyV7Migrate.lua` also opens Story after loading the tracked legacy fixture,
checks its active campaign and restores the saved map/position.

For all compiled text fields and the classic caller, build the disposable
capture fixture and run it against its matching symbol table:

```sh
python3 test/overworld/story-progress/build_fixture.py --out /tmp/pw-story
test/overworld/mgba-run.sh test/overworld/story-progress/capture.lua \
  /tmp/pw-story/VerifyFeatures.gba --elf /tmp/pw-story/VerifyFeatures.elf \
  --env PW_FEATURE_LIB=/tmp/pw-story/lua --out /tmp/pw-story-capture
```

The fixture is linked into verified unused ROM padding, never into the shipping
ROM. Native screenshots are unretouched. Layout checks use the production font
routine for all 820 objective fields, reject fields above three lines and check
screen navigation/restore behavior. State comparison uses decrypted bag data:
the normal return-to-field path relocates and re-encrypts the save blocks.
See the evidence for
the recorded build, hashes, checks and screenshots.

These checks establish targeted resolver/UI behavior. They do not certify full
continuous campaign or post-game playthroughs or every conceivable damaged save.
