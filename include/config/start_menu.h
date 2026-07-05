#ifndef GUARD_CONFIG_START_MENU_H
#define GUARD_CONFIG_START_MENU_H

// Unbound-style graphical start menu (sprite icons drawn over the live overworld), ported
// from miriamlefae/pokeemerald-expansion branch feat/usm/upcoming (see CREDITS.md).
// FALSE restores the classic text start menu everywhere; the Union Room/link menu and
// scripted opens (Task_OpenStartMenu) always use the classic menu regardless.
// Note: SaveBlock3.usmSaved stays in the save layout in both settings, so flipping this
// never shifts save data.
#define PW_GRAPHICAL_START_MENU     TRUE

#endif // GUARD_CONFIG_START_MENU_H
