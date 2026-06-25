#ifndef GUARD_CONFIG_NAME_BOX_H
#define GUARD_CONFIG_NAME_BOX_H

// Master flag for the Sword/Shield message + name box port. When FALSE the build is
// byte-identical vanilla (code and graphics); when TRUE it uses the SwSh message/name box.
#define SWSH_MESSAGE_BOX              TRUE

#define OW_FLAG_SUPPRESS_NAME_BOX   0  // If this flag is set, any namebox (whether its from a macro or a code) will not show up until this flag is unset.

// Namebox Speaker configs
#define OW_NAME_BOX_USE_DYNAMIC_WIDTH TRUE  // When TRUE, the namebox window can use different width depending on the length of the speaker's name.
#if SWSH_MESSAGE_BOX
#define OW_NAME_BOX_NPC_TRAINER       TRUE  // When TRUE, any approaching NPC trainers will have a namebox shown automagically. The name will be taken from their trainer data.
#else
#define OW_NAME_BOX_NPC_TRAINER       FALSE // When TRUE, any approaching NPC trainers will have a namebox shown automagically. The name will be taken from their trainer data.
#endif
#define OW_NAME_BOX_DEFAULT_WIDTH     8     // Maximum width of what OW_NAME_BOX_USE_DYNAMIC_WIDTH can set. Also the default width when the config above is set to FALSE (or the dynamic width exceeds this value).
#if SWSH_MESSAGE_BOX
#define OW_NAME_BOX_DEFAULT_HEIGHT    3     // Maximum height of the namebox window.
#else
#define OW_NAME_BOX_DEFAULT_HEIGHT    2     // Maximum height of the namebox window.
#endif

// Text colors of Namebox. The numbers corresponds to the palette index.
// The BG color is not provided as it always needs to be 0.
#define OW_NAME_BOX_FOREGROUND_COLOR  1
#if SWSH_MESSAGE_BOX
#define OW_NAME_BOX_SHADOW_COLOR      0
#else
#define OW_NAME_BOX_SHADOW_COLOR      2
#endif

#endif // GUARD_CONFIG_NAME_BOX_H
