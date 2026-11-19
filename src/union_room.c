#include "global.h"
#include "malloc.h"
#include "battle.h"
#include "berry_crush.h"
#include "bg.h"
#include "cable_club.h"
#include "data.h"
#include "decompress.h"
#include "dodrio_berry_picking.h"
#include "dynamic_placeholder_text_util.h"
#include "easy_chat.h"
#include "event_data.h"
#include "event_object_lock.h"
#include "fieldmap.h"
#include "field_control_avatar.h"
#include "field_player_avatar.h"
#include "field_screen_effect.h"
#include "field_weather.h"
#include "international_string_util.h"
#include "librfu.h"
#include "link.h"
#include "link_rfu.h"
#include "list_menu.h"
#include "load_save.h"
#include "menu.h"
#include "menu_helpers.h"
#include "mystery_gift.h"
#include "mystery_gift_menu.h"
#include "overworld.h"
#include "palette.h"
#include "party_menu.h"
#include "pokemon_jump.h"
#include "random.h"
#include "save_location.h"
#include "script.h"
#include "script_pokemon_util.h"
#include "sound.h"
#include "start_menu.h"
#include "string_util.h"
#include "strings.h"
#include "task.h"
#include "trade.h"
#include "trainer_card.h"
#include "union_room.h"
#include "union_room_battle.h"
#include "union_room_chat.h"
#include "union_room_player_avatar.h"
#include "window.h"
#include "constants/battle_frontier.h"
#include "constants/cable_club.h"
#include "constants/game_stat.h"
#include "constants/party_menu.h"
#include "constants/rgb.h"
#include "constants/songs.h"

// Six live single-player callers (trainer card, party menu, item use, ...)
// gate link-only behaviour on this. The room is unreachable, so: no.
bool32 InUnionRoom(void)
{
    return FALSE;
}

// On the LIVE nurse path of every POKeMON CENTER: the heal script asks whether
// a partner is waiting in the Union Room before offering the normal heal.
// 0 = nobody waiting, proceed to EventScript_PkmnCenterNurse_ReturnPkmn.
bool16 BufferUnionRoomPlayerName(void)
{
    return 0;
}

// The remaining specials are invoked only from scripts on the sealed 2Fs and
// their def_special rows keep the symbols hard link references. They decline
// synchronously and never stop the script context, so the caller simply
// continues; the real ones park the script and re-enable it from a task.
void InitUnionRoom(void)
{
}

void RunUnionRoom(void)
{
}

void Script_ResetUnionRoomTrade(void)
{
}

// Reachable live: the Battle Tower Multi-Link wireless flow calls these after
// its linkup. With every Try*Linkup declining they cannot be reached with a
// live link, but they still answer LINKUP_FAILED rather than trusting that.
void TryBecomeLinkLeader(void)
{
    gSpecialVar_Result = LINKUP_FAILED;
}

void TryJoinLinkGroup(void)
{
    gSpecialVar_Result = LINKUP_FAILED;
}

void SetUsingUnionRoomStartMenu(void)
{
}

// RAM state that outlives the module: trade.c keys its link-vs-ingame branches
// off gPlayerCurrActivity (and must stay byte-identical -- issue #59 keeps the
// in-game trades), and the party menu reads the offered-species/type/compat
// trio in its trade-eligibility checks. All are EWRAM, so keeping them defined
// costs no ROM; their initial values are the "no link activity" states those
// readers already treat as inert.
EWRAM_DATA u8 gPlayerCurrActivity = 0;
EWRAM_DATA struct RfuGameCompatibilityData gRfuPartnerCompatibilityData = {};
EWRAM_DATA enum Species gUnionRoomOfferedSpecies = SPECIES_NONE;
EWRAM_DATA enum Type gUnionRoomRequestedMonType = TYPE_NONE;

// The Mystery Gift menu's wireless-distribution flows and the Cable Club's
// wired-trade handoff create their link tasks HERE, in union_room.c -- inbound
// references the issue's file-level survey missed, found by the linker when
// this module was first flipped off. Both callers sit behind link setups that
// now always decline, so none of these can be reached with a live connection;
// the stubs exist to keep their modules linking while they remain compiled.
u8 CreateTask_CreateTradeMenu(void)
{
    return 0;
}

void CreateTask_LinkMysteryGiftWithFriend(u32 activity)
{
}

void CreateTask_LinkMysteryGiftOverWireless(u32 activity)
{
}

void CreateTask_SendMysteryGift(u32 activity)
{
}
