# Regional Story Progress Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans for shared integration; independent regional authoring follows superpowers:dispatching-parallel-agents. Steps use checkbox syntax for tracking.

**Goal:** Ship issue #353's read-only campaign reminder.

**Architecture:** A shared resolver reads existing save state and dispatches
to three source-backed regional tables. A small window screen renders an
overview and paged details; both Start menu styles enter the same screen.

**Tech Stack:** GBA C, pokeemerald-expansion windows/tasks, Python host checks,
patched mGBA Lua integration tests.

**Spec:** `docs/superpowers/specs/2026-09-29-story-progress.md`

## Global Constraints

- No save changes or second authoritative progression database.
- Shared items and generic Champion flags never establish regional completion.
- Hub default follows active campaign, not map-derived Hoenn.
- Native 240 x 160 screen; no legacy QUEST_MENU revival.
- Optional started chains remain distinct from main-story completion.

## Review Focus

- Partial/migrated saves: local scene progress establishes a started campaign.
- Bag-full rewards: guidance continues to name the unreceived prerequisite.
- Nonlinear badge order: guidance targets an available unmet prerequisite.
- Maximum classic menu rows: every action remains reachable on screen.
- Repeated screen visits: save state stays intact and allocated buffers free.

### Task 1: Resolver and regional content

**Files:** `include/story_progress.h`, `src/story_progress.c`,
`src/data/story_progress/{kanto,johto,hoenn}.inc`,
`test/overworld/story-progress/{test.c,run.py,*_cases.inc,shim/*}`,
`docs/story-progress/{kanto,johto,hoenn}.md`.

**Interfaces:** `StoryProgress_Resolve(enum Region, struct StoryProgress *)`
produces status, badge count, objective and optional-objective pointers.
Regional functions return `const struct StoryObjective *` and use F/V/B/I
read-only accessors. Tests call `Expect(region, "stable.id")` against C.

- [x] Write host tests for not-started, active/default, isolated badges,
  Champion precedence and regional transitions. Run `python3 test/overworld/story-progress/run.py`
  and confirm missing implementation fails.
- [x] Implement shared resolver and three independently authored regional
  resolvers. Cover every objective and immediately adjacent transition.
- [x] Run host tests; inspect source documents and retry/overlap cases.

### Task 2: Screen and menu entry

**Files:** `src/story_progress_menu.c`, `src/start_menu.c`,
`src/unbound_start_menu.c`, `test/overworld/story-progress/fixture.c`,
`test/overworld/story-progress/capture.lua`.

**Interfaces:** `ShowStoryProgress(MainCallback returnCallback)` opens the
screen, reads current state, and frees all owned windows on return.

- [x] Write emulator expectations for entry, three regions, paging, B/back,
  state snapshot equality and repeated heap restoration.
- [x] Implement the window screen and both menu entries. Reuse the dormant
  graphical quest icon's numeric slot, preserving saved menu layout.
- [x] Make the classic menu scroll with eight visible rows.
- [x] Build and run the fixture. Check every authored string with the actual
  font-width function and retain native screenshots/provenance.

### Task 3: Gates, documentation and review

**Files:** `Makefile`, `.github/workflows/Check.yml`,
`test/overworld/hooks/pre-push`, `README.md`, `FEATURES.md`,
`docs/story-progress/README.md`.

- [x] Add host resolver check to validation, CI and pre-push.
- [x] Document controls/access, coverage, data sources and verification limits.
- [x] Run `make modern TOOLCHAIN=/opt/devkitpro/devkitARM -j8`, `make validate`,
  `make check`, story emulator suite and `test/overworld/run-all.sh`.
- [x] Review the complete diff independently, fix material findings and
  rerun affected checks. Commit implementation and prepare a reviewable PR.
