#ifndef GUARD_CONFIG_QUICKSTART_H
#define GUARD_CONFIG_QUICKSTART_H

#define GENDER_MALE              0
#define GENDER_FEMALE            1
#define GENDER_RANDOM            2

// Quickstart Settings
#define ENABLE_QUICKSTART            FALSE // Keep SELECT from bypassing the main menu and starting a new game.
#define QUICKSTART_HUD               FALSE // No SELECT / New Game badge on the title screen.
#define QUICKSTART_GENDER            GENDER_RANDOM

#define QUICKSTART_HUD_X             (DISPLAY_WIDTH - 32) // Quickstart HUD X Position
#define QUICKSTART_HUD_Y             (16)                 // Quickstart HUD Y Position

#endif // GUARD_CONFIG_QUICKSTART_H
