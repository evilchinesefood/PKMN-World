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
the overview, then the original Start menu. A Champion region retains **Main
story complete** even if an optional chain remains unfinished. The recap is
the latest established milestone derived from the current state, not an
invented chronological activity log.

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
states and save purity. It is part of `make validate`, CI and the pre-push gate.
On macOS it pairs the selected Xcode compiler with that Xcode's SDK; `CC` and
`SDKROOT` overrides remain available.

`test/overworld/lua/StoryProgress.lua` drives the production Start menu through
Kanto → Johto → Hoenn → hub → Kanto, opens every region without travelling,
checks active defaults/state/heap restoration, saves, reboots and Continues.
It is included in `test/overworld/run-all.sh`. Existing save tests select the
Save action by ID instead of relying on its position next to the new Story icon.
`VerifyV7Migrate.lua` also opens Story after loading the tracked legacy fixture,
checks its active campaign and restores the saved map/position.

For all compiled text fields and the classic caller, build the disposable
capture fixture and run it against its matching symbol table:

```sh
python3 test/overworld/story-progress/build_fixture.py --out /tmp/pw-story
PW_FEATURE_LIB=/tmp/pw-story/lua PW_OUT=/tmp/pw-story-capture \
  test/overworld/mgba-run.sh test/overworld/story-progress/capture.lua \
  /tmp/pw-story/VerifyFeatures.gba
```

The fixture is linked into verified unused ROM padding, never into the shipping
ROM. Native screenshots are unretouched. Layout checks use the production font
routine for all 820 objective fields, reject fields above three lines and check
screen navigation/restore behavior. State comparison uses decrypted bag data:
the normal return-to-field path relocates and re-encrypts the save blocks.
See the [evidence](../../test/overworld/story-progress/evidence/README.md) for
the recorded build, hashes, checks and screenshots.

These checks establish targeted resolver/UI behavior. They do not certify full
continuous campaign or post-game playthroughs or every conceivable damaged save.
