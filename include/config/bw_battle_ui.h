#ifndef GUARD_CONFIG_BW_BATTLE_UI_H
#define GUARD_CONFIG_BW_BATTLE_UI_H

// General identifier that may be referenced in other feature branches.
#define BW_BATTLE_UI                (TRUE)

// Specific toggle for mix-n-match ui elements.
// This is NOT recommended if you want to use this as a base for your own UI!

#define BW_BATTLE_UI_TEXTBOX        (BW_BATTLE_UI)  // Enables BW1-styled textbox. If BW_BATTLE_UI_INPUTBOX is FALSE, uses gen3-styled navigation menu instead.
#define BW_BATTLE_UI_INPUTBOX       (BW_BATTLE_UI)  // Various elements related to navigation e.g. executing a move, use an item, or running away. Requires BW_BATTLE_UI_TEXTBOX.
#define BW_BATTLE_UI_PARTY_SUMMARY  (BW_BATTLE_UI)  // Party summary bar, typically ball_status_bar and ball_display.
#define BW_BATTLE_UI_HEALTHBOX      (BW_BATTLE_UI)  // The real jam. Includes custom status ailment gfx and outlined font as well.
#define BW_BATTLE_UI_ABILITY_POP_UP (BW_BATTLE_UI)  // Another real jam. Replaces expansion's functionality, includes customized animation.
#define BW_BATTLE_UI_WINDOW_SPRITES (BW_BATTLE_UI)  // Both Last Used Ball and Move Description trigger sprites are handled here.

// Config safeguards, do not delete unless you know what you're doing!
#if BW_BATTLE_UI && (B_MOVE_REARRANGEMENT_IN_BATTLE < GEN_4)
#error "pokeemerald-expansion's `B_MOVE_REARRANGEMENT_IN_BATTLE' config is unsupported by `BW_BATTLE_UI'!"
#endif

#if (BW_BATTLE_UI_TEXTBOX != TRUE && BW_BATTLE_UI_INPUTBOX == TRUE)
#error "The config `BW_BATTLE_UI_INPUTBOX' requires `BW_BATTLE_UI_TEXTBOX' to be both set to `TRUE'!"
#endif

#endif // GUARD_CONFIG_BW_BATTLE_UI_H
