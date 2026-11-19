#include "global.h"
#include "main.h"
#include "battle.h"
#include "battle_records.h"
#include "battle_setup.h"
#include "cable_club.h"
#include "data.h"
#include "event_data.h"
#include "field_message_box.h"
#include "field_specials.h"
#include "field_weather.h"
#include "international_string_util.h"
#include "link.h"
#include "link_rfu.h"
#include "load_save.h"
#include "m4a.h"
#include "menu.h"
#include "overworld.h"
#include "palette.h"
#include "union_room.h"
#include "mystery_gift.h"
#include "script.h"
#include "script_pokemon_util.h"
#include "sound.h"
#include "start_menu.h"
#include "string_util.h"
#include "strings.h"
#include "task.h"
#include "trade.h"
#include "trainer_card.h"
#include "party_menu.h"
#include "window.h"
#include "constants/battle_frontier.h"
#include "constants/cable_club.h"
#include "constants/songs.h"
#include "constants/trainers.h"

// The linkup specials are REACHABLE from live single-player maps: the Battle
// Tower Multi-Link attendant, the contest hall's link modes and the Berry
// Blender link corners. Their calling scripts do NOT waitstate -- the real
// specials stop the script context themselves and their UI tasks re-enable it
// -- so a synchronous stub that sets the result and never stops the context
// makes the script branch immediately: a graceful decline, no softlock.
void TryBattleLinkup(void)
{
    gSpecialVar_Result = LINKUP_FAILED;
}

void TryTradeLinkup(void)
{
    gSpecialVar_Result = LINKUP_FAILED;
}

void TryRecordMixLinkup(void)
{
    gSpecialVar_Result = LINKUP_FAILED;
}

void TryBerryBlenderLinkup(void)
{
    gSpecialVar_Result = LINKUP_FAILED;
}

void TryContestGModeLinkup(void)
{
    gSpecialVar_Result = LINKUP_FAILED;
}

void TryContestEModeLinkup(void)
{
    gSpecialVar_Result = LINKUP_FAILED;
}

// Selects the wired-vs-wireless battle-tower link type ahead of a linkup that
// now always fails; nothing downstream reads what it would have set.
void TrySetBattleTowerLinkType(void)
{
}

// The rest are invoked only from scripts inside the link rooms themselves,
// which lost their only door when the 2F staircases were sealed.
void CableClubSaveGame(void)
{
}

void CleanupLinkRoomState(void)
{
}

void ColosseumPlayerSpotTriggered(void)
{
}

void PlayerEnteredTradeSeat(void)
{
}

void ExitLinkRoom(void)
{
}

void Script_ShowLinkTrainerCard(void)
{
}

void Script_StartWiredTrade(void)
{
}

// The record-mix language gate, reached only past a TryRecordMixLinkup that
// now always fails; CONNECTION_ERROR routes its script to the shared abort.
void ValidateMixingGameLanguage(void)
{
    gSpecialVar_Result = LINKUP_CONNECTION_ERROR;
}

// overworld.c picks the plain vs coloured trainer-card script off this.
bool32 GetLinkTrainerCardColor(u8 linkPlayerIndex)
{
    return FALSE;
}

// Task_ReturnToFieldCableLink (field_screen_effect.c) polls the returned task
// id for completion. Only reachable when returning to the field from a link
// room, which no longer has a door; 0 satisfies the signature.
u8 CreateTask_ReestablishCableClubLink(void)
{
    return 0;
}

// Referenced by battle_main.c / battle_controllers.c / trade.c link paths that
// stay compiled. If one is ever created it must not wedge the task list.
void Task_ReconnectWithLinkPlayers(u8 taskId)
{
    DestroyTask(taskId);
}

void Task_WaitForLinkPlayerConnection(u8 taskId)
{
    DestroyTask(taskId);
}
