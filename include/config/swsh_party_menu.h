#ifndef GUARD_CONFIG_SWSH_PARTY_MENU_H
#define GUARD_CONFIG_SWSH_PARTY_MENU_H

#define SWSH_PARTY_MENU                   TRUE  // Must stay TRUE: the classic party menu (src/party_menu.c) was deleted.
#define SWSH_PARTY_MENU_PC_ACCESS         TRUE
#define SWSH_PARTY_MON_IDLE_ANIMS         TRUE
#define SWSH_PARTY_MON_IDLE_ANIMS_FRAMES  300 // Number of frames before mon animation loops

#if !SWSH_PARTY_MENU
#error "SWSH_PARTY_MENU FALSE no longer builds: the classic party menu source was deleted. Restore src/party_menu.c from git history first."
#endif

#endif // GUARD_CONFIG_SWSH_PARTY_MENU_H
