#ifndef GUARD_CONFIG_LINK_H
#define GUARD_CONFIG_LINK_H

// Link-feature off-switches (issue #59 part E). The Battle Net terminal rework
// sealed every POKéMON CENTER 2F, which was the only door to the Union Room,
// Wireless Club, Mystery Gift man and Record Corner -- so their code follows.
// Each flag compiles one feature's modules to nothing; the stub arms inside the
// guarded files keep every externally-referenced symbol defined, so
// data/specials.inc and data/script_cmd_table.inc are COMPLETELY untouched
// (both are index-based tables where a conditional row silently renumbers
// everything after it in test builds -- the 9ee61fbd class).
//
// What deliberately STAYS compiled regardless of these flags:
//   - src/mystery_gift.c      already stubbed per-function by FREE_MYSTERY_GIFT;
//                             keeping it resolves 7 cross-module callers for 551 B
//   - src/ereader_helpers.c   houses ReadTrainerHillAndValidate -- Trainer Hill
//                             is live single-player content
//   - src/trade.c             hosts the in-game trades; byte-identical by design
//   - link.o, link_rfu_*, AgbRfu_LinkManager, contest_link  (the low-level link
//                             layer, referenced from battle and contest code --
//                             deferred deliberately)
//
// ⚠ These flags do NOT move the save layout in either direction. The save
// fields the removed code owned (registeredTexts, hallRecords, linkBattleRecords,
// recordMixingGift) are replaced by same-size reserved padding unconditionally,
// so flipping a flag back TRUE also requires reverting that padding commit.
// Never flip the FREE_* flags in config/save.h for symmetry -- they free SAVE
// bytes, not ROM, and shift flags/vars/bag (silent save break).

// Union Room + Wireless Club Chat + the wireless communication status screen
// (the status screen depends on CreateTask_ListenToWireless in union_room.c,
// so it rides this flag rather than owning one).
#define LINK_UNION_ROOM     FALSE

// Mystery Gift menu/client/server/link/scripts + Wonder News + the e-Reader
// screen (CB2_InitEReader lives in mystery_gift_menu.c, so the e-Reader rides
// this flag). src/mystery_gift.c itself stays as the stub host.
#define LINK_MYSTERY_GIFT   FALSE

// Mystery Event menu + script interpreter + messages. The setmysteryeventstatus
// opcode row is untouched; the handler in scrcmd.c keeps consuming its byte and
// simply stops forwarding it (no script in the tree invokes the opcode).
#define LINK_MYSTERY_EVENT  FALSE

// Record mixing. GetPlayerHallRecords was moved to frontier_util.c first --
// the Battle Frontier Ranking Hall is live single-player content.
#define LINK_RECORD_MIXING  FALSE

// The Cable Club link-room machinery. Its scripts in data/scripts/cable_club*.inc
// stay assembling (they also host the Battle Colosseum / TradeCenter /
// RecordCorner room scripts and non-link content); the Try*Linkup specials they
// invoke become synchronous decline stubs, because the Battle Tower Multi-Link,
// contest-hall link modes and Berry Blender link corners are reachable in
// normal single-player play and must decline gracefully, not softlock.
#define LINK_CABLE_CLUB     TRUE

// Two real dependencies the issue's file-level survey missed, both found by
// the linker on the first wrong-order flip attempts:
//   - the Union Room UI borrows the Mystery Gift menu's text machinery
//     (union_room.c calls DoMysteryGiftYesNo, GetMysteryGiftBaseBlock,
//     MG_AddMessageTextPrinter, MG_DrawTextBorder, PrintMysteryGiftMenuMessage)
//   - the Mystery Gift client executes mystery-event scripts delivered over
//     the wire (mystery_gift_client.c calls InitMysteryEventScriptContext /
//     RunMysteryEventScriptContextCommand)
// So the only valid removal order is union_room -> mystery_gift ->
// mystery_event, the reverse of the issue's step 10.
#if LINK_UNION_ROOM == TRUE && LINK_MYSTERY_GIFT == FALSE
#error "LINK_UNION_ROOM requires LINK_MYSTERY_GIFT: union_room.c borrows the gift menu's text machinery."
#endif
#if LINK_MYSTERY_GIFT == TRUE && LINK_MYSTERY_EVENT == FALSE
#error "LINK_MYSTERY_GIFT requires LINK_MYSTERY_EVENT: mystery_gift_client.c executes mystery-event scripts."
#endif

#endif // GUARD_CONFIG_LINK_H
